(local {: autoload} (require :conjure.nfnl.module))
(local editor (autoload :conjure.editor))
(local log (autoload :grapple.client.log))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))
(local str (autoload :conjure.nfnl.string))
(local ui (autoload :grapple.client.ui))
(local debugger (autoload :grapple.client.debugger))

(fn show-nls [s]
  (let [with-arrows (string.gsub s "\r?\n" "↵\n")
        lines (str.split with-arrows "\n")]
    ; Remove empty last element if present (from trailing newline)
    (when (and (> (length lines) 1) (= "" (n.last lines)))
      (table.remove lines))
    lines))

(fn upcase [s n]
  (let [start (string.sub s 1 n)
        rest (string.sub s (+ n 1))]
    (.. (string.upper start) rest)))

(fn render-janet-value [janet-result st]
  "Recursively renders janet/result, eliding complex types with > 20 elements"
  (if
    ; Simple type - already a string
    (= (type janet-result) "string")
    janet-result
    ; Complex type
    (and (= (type janet-result) "table")
         (. janet-result :type))
    (let [result-type (. janet-result :type)
          result-count (or (. janet-result :count) 0)
          result-length (or (. janet-result :length) 0)]
      (if
        ; Three-step heuristic:
        ; 1. if length <= 50: render fully
        ; 2. if length > 50 and count > 20: elide
        ; 3. if length > 50 but count <= 20: render and recurse
        (and (> result-length 50) (> result-count 20))
        (let [counter (+ (. st :result-counter) 1)
              id-str (string.format "%04x" counter)]
          (n.assoc st :result-counter counter)
          (n.assoc (. st :id-to-val) id-str janet-result)
          (.. "<" result-type "-" id-str " count:" result-count ">"))
        ; Otherwise render normally based on type
        (case result-type
          "array"
          (.. "@[" (str.join " " (n.map #(render-janet-value $ st) (or (. janet-result :els) []))) "]")
          "tuple"
          (.. "[" (str.join " " (n.map #(render-janet-value $ st) (or (. janet-result :els) []))) "]")
          "struct"
          (let [kvs (or (. janet-result :kvs) [])
                pairs []]
            (for [i 1 (length kvs) 2]
              (let [k (. kvs i)
                    v (. kvs (+ i 1))]
                (table.insert pairs (.. (render-janet-value k st) " " (render-janet-value v st)))))
            (.. "{" (str.join " " pairs) "}"))
          "table"
          (let [kvs (or (. janet-result :kvs) [])
                pairs []]
            (for [i 1 (length kvs) 2]
              (let [k (. kvs i)
                    v (. kvs (+ i 1))]
                (table.insert pairs (.. (render-janet-value k st) " " (render-janet-value v st)))))
            (.. "@{" (str.join " " pairs) "}"))
          ; Unknown type - return the :value field
          _
          (. janet-result :value))))
    ; Not a string or complex type - shouldn't happen, return nil
    nil))

(fn render-result [resp]
  "Renders a result value, truncating complex types and returning a display string"
  (let [val (or resp.val "")
        janet-result (. resp "janet/result")]
    (if
      ; If val is short enough, just display it
      (< (length val) 50)
      val

      ; If janet/result exists, try selective rendering
      janet-result
      (render-janet-value janet-result (state.get))

      ; Otherwise, display val
      val)))

(fn error-msg? [msg]
  (= "err" msg.tag))

(fn display-error [desc msg]
  (log.append :error [desc])
  (when (and msg msg.janet/path msg.janet/line msg.janet/col)
    (log.append :error
                [(.. " in " msg.janet/path
                     " on line " msg.janet/line
                     " at col " msg.janet/col)])))

(fn handle-sess-new [resp]
  (n.assoc (state.get :conn) :session resp.sess)
  (let [[impl-name impl-ver] resp.janet/impl
        [serv-name serv-ver] resp.janet/serv]
    (log.append :info
                [(.. "Connected to " (upcase serv-name 1)
                     " v" serv-ver
                     " running " (upcase impl-name 1)
                     " v" impl-ver
                     " as session " resp.sess)])))

(fn handle-cmd [resp]
  (if
    (= "clear-breakpoints" resp.val)
    (let [bp-ids (. resp "janet/breakpoints")
          breakpoints (state.get :breakpoints)
          removed-locations []]
      (each [_ bp-id (ipairs bp-ids)]
        ; Find the sign-id for this bp-id
        (each [sign-id bp-data (pairs breakpoints)]
          (when (= bp-data.bp-id bp-id)
            (let [current-line (ui.get-sign-current-line sign-id)]
              (when current-line
                (table.insert removed-locations (.. bp-data.file-path ":" current-line)))
              (ui.remove-breakpoint-sign sign-id)
              (lua "break")))))
      (each [_ location (ipairs removed-locations)]
        (log.append :info [(.. "Removed stale breakpoint at " location)])))))

(fn handle-env-eval [resp opts]
  (if
    (= nil resp.val)
    nil ; do nothing if no value to print

    (and (= "out" resp.tag) (= "out" resp.ch))
    (log.append :stdout (show-nls resp.val))

    (and (= "out" resp.tag) (= "err" resp.ch))
    (log.append :stderr [resp.val])

    (= "cmd" resp.tag)
    (handle-cmd resp)

    (= "note" resp.tag)
    (log.append :note [resp.val])

    (and (= "sig" resp.tag) (= "debug" resp.val))
    (debugger.handle-signal resp)

    (and (= "ret" resp.tag) (not= nil resp.val))
    (do
      ; Only show virtual text for primary results (not cascaded reevaluations)
      (let [rendered (render-result resp)]
        (if rendered
          (do
            (when (and opts.on-result (not (. resp "janet/reeval?")))
              (opts.on-result rendered))
            (log.append :result [rendered]))
          (log.append :error ["Failed to render result: unexpected janet/result structure"]))))))

(fn handle-env-dbg [resp opts]
  "Handles env.dbg responses (debug commands), logging ret to debug section"
  (if
    ; For debug commands, log return values to debug section (not result)
    (and (= "ret" resp.tag) (not= nil resp.val))
    (let [rendered (render-result resp)]
      (if rendered
        (log.append :result [rendered])
        (log.append :error ["Failed to render result: unexpected janet/result structure"])))

    ; Delegate everything else to handle-env-eval
    (handle-env-eval resp opts)))

(fn handle-env-doc [resp action]
  (if
    (= "doc" action)
    (let [src-buf (vim.api.nvim_get_current_buf)
          buf (vim.api.nvim_create_buf false true)
          sm-info (.. resp.janet/type
                      "\n"
                      (if (not resp.janet/sm)
                        "\n"
                        (let [[path line col] resp.janet/sm]
                          (.. path " on line " line ", column " col "\n\n"))))
          lines (str.split (.. sm-info resp.val) "\n")
          _ (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
          width 50
          height 10
          win-opts {:relative "cursor"
                    :width width
                    :height height
                    :col 0
                    :row 1
                    :anchor "NW"
                    :style "minimal"
                    :border "rounded"}
          win (vim.api.nvim_open_win buf true win-opts)]
      (vim.keymap.set :n "j" "gj" {:buffer buf :noremap true :silent true})
      (vim.keymap.set :n "k" "gk" {:buffer buf :noremap true :silent true})
      (vim.keymap.set :n "<Down>" "gj" {:buffer buf :noremap true :silent true})
      (vim.keymap.set :n "<Up>" "gk" {:buffer buf :noremap true :silent true})
      (vim.keymap.set :n "q" ":q<CR>" {:buffer buf :noremap true :silent true})
      (vim.keymap.set :n "<Esc>" ":q<CR>" {:buffer buf :noremap true :silent true})
      (vim.api.nvim_buf_set_option buf "wrap" true)
      (vim.api.nvim_buf_set_option buf "linebreak" true)
      (vim.api.nvim_buf_set_option buf "filetype" "markdown")
      (vim.api.nvim_win_set_option win "scrolloff" 0)
      (vim.api.nvim_win_set_option win "sidescrolloff" 0)
      (vim.api.nvim_win_set_option win "breakindent" true)
      (vim.api.nvim_create_autocmd :CursorMoved
                                   {:buffer src-buf
                                    :once true
                                    :callback (fn []
                                                (when (vim.api.nvim_win_is_valid win)
                                                  (vim.api.nvim_win_close win true))
                                                (vim.api.nvim_buf_delete buf {:force true})
                                                nil)}))
    (= "def" action)
    (let [[path line col] resp.janet/sm
          stat (vim.loop.fs_stat path)]
      (if (and stat (= "file" stat.type))
        (editor.go-to path line col)
        (display-error "Oh no")))))

(fn handle-brk-add [resp opts]
  (if
    (= "ret" resp.tag)
    (do
      (let [bp-id (. resp "janet/bp-id")]
        (log.append :info [(.. "Added breakpoint at " opts.file-path ":" opts.line)])
        (ui.add-breakpoint-sign opts.bufnr opts.file-path opts.line bp-id)))
    (= "err" resp.tag)
    (display-error (.. "Failed to add breakpoint: " resp.val) resp)))

(fn handle-brk-rem [resp opts]
  (if
    (= "ret" resp.tag)
    (do
      (let [breakpoints (state.get :breakpoints)
            bp-data (. breakpoints opts.sign-id)
            current-line (ui.get-sign-current-line opts.sign-id)]
        (when (and bp-data current-line)
          (log.append :info [(.. "Removed breakpoint at " bp-data.file-path ":" current-line)]))
        (ui.remove-breakpoint-sign opts.sign-id)))
    (= "err" resp.tag)
    (display-error (.. "Failed to remove breakpoint: " resp.val) resp)))

(fn handle-brk-clr [resp]
  (if
    (= "ret" resp.tag)
    (do
      (log.append :info ["Cleared all breakpoints"])
      (ui.clear-breakpoint-signs))
    (= "err" resp.tag)
    (display-error (.. "Failed to clear breakpoints: " resp.val) resp)))

(fn handle-brk-list [resp opts]
  (if
    (= "ret" resp.tag)
    (let [rendered (render-result resp)]
      (if rendered
        (log.append :result [rendered])
        (log.append :error ["Failed to render result: unexpected janet/result structure"])))
    (= "err" resp.tag)
    (display-error (.. "Failed to list breakpoints: " resp.val) resp)))

(fn handle-message [msg opts]
  (when msg
   (let [action (or (and opts opts.action) nil)]
     (if
      ; Check for authentication errors first (special case)
      (and (error-msg? msg)
           (= "sess.new" msg.op)
           (string.find (or msg.val "") "authentication failed")
           opts.on-auth-error)
      (opts.on-auth-error)

      ; Regular error handling
      (error-msg? msg)
      (display-error msg.val msg)

      (= "sess.new" msg.op)
      (handle-sess-new msg)

      (= "sess.end" msg.op)
      (handle-sess-end msg)

      (= "sess.list" msg.op)
      (handle-sess-list msg)

      (= "mgmt.info" msg.op)
      (handle-mgmt-info msg)

      (= "mgmt.stop" msg.op)
      (handle-mgmt-stop msg)

      (= "mgmt.rest" msg.op)
      (handle-mgmt-rest msg)

      (= "env.eval" msg.op)
      (handle-env-eval msg opts)

      (= "env.load" msg.op)
      (handle-env-eval msg opts)

      (= "env.stop" msg.op)
      (handle-env-stop msg)

      (= "env.doc" msg.op)
      (handle-env-doc msg action)

      (= "env.cmpl" msg.op)
      (handle-env-cmpl msg)

      (= "env.dbg" msg.op)
      (handle-env-dbg msg opts)

      (= "brk.add" msg.op)
      (handle-brk-add msg opts)

      (= "brk.rem" msg.op)
      (handle-brk-rem msg opts)

      (= "brk.clr" msg.op)
      (handle-brk-clr msg)

      (= "brk.list" msg.op)
      (handle-brk-list msg opts)

      (do
        (log.append :error ["Unrecognised message"]))))))

{: handle-message}

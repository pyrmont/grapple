(local {: autoload} (require :conjure.nfnl.module))
(local editor (autoload :conjure.editor))
(local log (autoload :grapple.client.log))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))
(local str (autoload :conjure.nfnl.string))
(local ui (autoload :grapple.client.ui))

(fn upcase [s n]
  (let [start (string.sub s 1 n)
        rest (string.sub s (+ n 1))]
    (.. (string.upper start) rest)))

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
        (log.append :debug [(.. "Removed stale breakpoint at " location)])))))

(fn handle-env-eval [resp opts]
  (if
    (= nil resp.val)
    nil ; do nothing if no value to print

    (and (= "out" resp.tag) (= "out" resp.ch))
    (log.append :stdout [resp.val])

    (and (= "out" resp.tag) (= "err" resp.ch))
    (log.append :stderr [resp.val])

    (= "cmd" resp.tag)
    (handle-cmd resp)

    (= "note" resp.tag)
    (log.append :note [resp.val])

    (and (= "sig" resp.tag) (= "debug" resp.val))
    (let [location (if (and resp.janet/path resp.janet/line)
                     (.. " at " resp.janet/path ":" resp.janet/line)
                     "")]
      (log.append :debug [(.. "Paused at breakpoint" location)])
      (log.append :debug ["Use <localleader>dis to inspect stack, <localleader>dsc to continue"])
      ; Show visual debug indicators
      (when (and resp.janet/path resp.janet/line)
        (let [file-path resp.janet/path
              line resp.janet/line
              ; Find the buffer for this file
              bufnr (vim.fn.bufnr file-path)]
          (when (not= bufnr -1)
            (ui.show-debug-indicators bufnr file-path line)))))

    (and (= "ret" resp.tag) (not= nil resp.val))
    (do
      ; Only show virtual text for primary results (not cascaded reevaluations)
      (when (and opts.on-result (not (. resp "janet/reeval?")))
        (opts.on-result resp.val))
      (log.append :result [resp.val]))))

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

(fn handle-dbg-brk-add [resp opts]
  (if
    (= "ret" resp.tag)
    (do
      (let [bp-id (. resp "janet/bp-id")]
        (log.append :debug [(.. "Added breakpoint at " opts.file-path ":" opts.line)])
        (ui.add-breakpoint-sign opts.bufnr opts.file-path opts.line bp-id)))
    (= "err" resp.tag)
    (display-error (.. "Failed to add breakpoint: " resp.val) resp)))

(fn handle-dbg-brk-rem [resp opts]
  (if
    (= "ret" resp.tag)
    (do
      (let [breakpoints (state.get :breakpoints)
            bp-data (. breakpoints opts.sign-id)
            current-line (ui.get-sign-current-line opts.sign-id)]
        (when (and bp-data current-line)
          (log.append :debug [(.. "Removed breakpoint at " bp-data.file-path ":" current-line)]))
        (ui.remove-breakpoint-sign opts.sign-id)))
    (= "err" resp.tag)
    (display-error (.. "Failed to remove breakpoint: " resp.val) resp)))

(fn handle-dbg-brk-clr [resp]
  (if
    (= "ret" resp.tag)
    (do
      (log.append :debug ["Cleared all breakpoints"])
      (ui.clear-breakpoint-signs))
    (= "err" resp.tag)
    (display-error (.. "Failed to clear breakpoints: " resp.val) resp)))

(fn handle-dbg-step-cont [resp]
  (if
    (= "ret" resp.tag)
    (do
      ; (log.append :debug ["Continued execution"])
      ; Hide debug indicators when execution continues
      (ui.hide-debug-indicators))
    (= "err" resp.tag)
    (display-error (.. "Failed to continue: " resp.val) resp)))

(fn handle-dbg-insp-stk [resp]
  (if
    (and (= "ret" resp.tag) resp.val)
    (do
      ; (log.append :debug ["Stack frames:"])
      (log.append :result [resp.val]))
    (= "ret" resp.tag)
    (log.append :debug ["No stack frames available"])
    (= "err" resp.tag)
    (display-error (.. "Failed to inspect stack: " resp.val) resp)))

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

      (= "serv.info" msg.op)
      (handle-sess-info msg)

      (= "serv.stop" msg.op)
      (handle-serv-stop msg)

      (= "serv.rest" msg.op)
      (handle-serv-rest msg)

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

      (= "dbg.brk.add" msg.op)
      (handle-dbg-brk-add msg opts)

      (= "dbg.brk.rem" msg.op)
      (handle-dbg-brk-rem msg opts)

      (= "dbg.brk.clr" msg.op)
      (handle-dbg-brk-clr msg)

      (= "dbg.step.cont" msg.op)
      (handle-dbg-step-cont msg)

      (= "dbg.insp.stk" msg.op)
      (handle-dbg-insp-stk msg)

      (do
        (log.append :error ["Unrecognised message"]))))))

{: handle-message}

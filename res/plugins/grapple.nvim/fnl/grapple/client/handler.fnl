(local {: autoload} (require :conjure.nfnl.module))
(local editor (autoload :conjure.editor))
(local log (autoload :grapple.client.log))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))
(local str (autoload :conjure.nfnl.string))

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

(fn handle-env-eval [resp opts]
  (if
    (= nil resp.val)
    nil ; do nothing if no value to print

    (and (= "out" resp.tag) (= "out" resp.ch))
    (log.append :stdout [resp.val])

    (and (= "out" resp.tag) (= "err" resp.ch))
    (log.append :stderr [resp.val])

    (= "note" resp.tag)
    (log.append :note [resp.val])

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

      (do
        (log.append :error ["Unrecognised message"]))))))

{: handle-message}

(local {: autoload} (require :nfnl.module))
(local editor (autoload :conjure.editor))
(local log (autoload :conjure.log))
(local n (autoload :nfnl.core))
(local state (autoload :grapple.client.state))
(local str (autoload :nfnl.string))

(fn upcase [s n]
  (let [start (string.sub s 1 n)
        rest (string.sub s (+ n 1))]
    (.. (string.upper start) rest)))

(fn error-msg? [msg]
  (= "err" msg.tag))

(fn display-error [msg]
  (log.append [(.. "# ! " msg)]))

(fn handle-sess-new [resp]
  (n.assoc (state.get :conn) :session resp.sess)
  (let [[impl-name impl-ver] resp.janet/impl
        [serv-name serv-ver] resp.janet/serv]
    (log.append [(.. "# Connected to "
                     (upcase serv-name 1)
                     " v"
                     serv-ver
                     " running "
                     (upcase impl-name 1)
                     " v"
                     impl-ver
                     " as session "
                     resp.sess)])))

(fn handle-env-eval [resp]
  (if
    (and (= "out" resp.tag) (= "out" resp.ch))
    (log.append [(.. "# (out) " resp.val)])

    (and (= "out" resp.tag) (= "err" resp.ch))
    (log.append [(.. "# (err) " resp.val)])

    (log.append [resp.val])))

(fn handle-env-doc [resp action]
  (if
    (= "doc" action)
    (let [buf (vim.api.nvim_create_buf false true)
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
          win (vim.api.nvim_open_win buf false win-opts)]
     (vim.api.nvim_buf_set_option buf "wrap" true)
     (vim.api.nvim_buf_set_option buf "linebreak" true)
     (vim.api.nvim_buf_set_option buf "filetype" "markdown")
     (vim.api.nvim_create_autocmd :CursorMoved
                                  {:once true
                                   :callback (fn []
                                               (vim.api.nvim_win_close win true)
                                               (vim.api.nvim_buf_delete buf {:force true})
                                               nil)}))
    (= "def" action)
    (let [[path line col] resp.janet/sm
          stat (vim.loop.fs_stat path)]
      (if (and stat (= "file" stat.type))
        (editor.go-to path line col)
        (display-error "Oh no")))))

(fn handle-message [msg action]
  (when msg
   (if
    (error-msg? msg)
    (display-error msg.msg)

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
    (handle-env-eval msg)

    (= "env.load" msg.op)
    (handle-env-eval msg) ; OK?

    (= "env.stop" msg.op)
    (handle-env-stop msg)

    (= "env.doc" msg.op)
    (handle-env-doc msg action)

    (= "env.cmpl" msg.op)
    (handle-env-cmpl msg)

    (do
      (log.append ["# Unrecognised message"])))))

{: handle-message}

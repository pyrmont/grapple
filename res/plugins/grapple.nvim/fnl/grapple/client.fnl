(local {: autoload} (require :nfnl.module))
(local config (autoload :conjure.config))
(local handler (autoload :grapple.client.handler))
(local log (autoload :grapple.client.log))
(local mapping (autoload :conjure.mapping))
(local n (autoload :nfnl.core))
(local remote (autoload :grapple.remote))
(local request (autoload :grapple.client.request))
(local state (autoload :grapple.client.state))
(local ts (autoload :conjure.tree-sitter))

(local buf-suffix ".janet")
(local comment-prefix "# ")
(local comment-node? ts.lisp-comment-node?)
(local form-node? ts.node-surrounded-by-form-pair-chars?)

(config.merge
  {:client
   {:janet
    {:mrepl
     {:connection {:default_host "127.0.0.1"
                   :default_port "3737"
                   :lang "net.inqk/janet-1.0"}}}}})

(when (config.get-in [:mapping :enable_defaults])
  (config.merge
    {:client
     {:janet
      {:mrepl
       {:mapping {:connect "cc"
                  :disconnect "cd"
                  :start-server "cs"
                  :stop-server "cS"}}}}}))

(fn start-server [opts]
  (let [host (or opts.host (config.get-in [:client :janet :mrepl :connection :default_host]))
        port (or opts.port (config.get-in [:client :janet :mrepl :connection :default_port]))
        here (n.first (vim.api.nvim_get_runtime_file "fnl/grapple/client.fnl" false))
        root (-> (vim.fs.dirname here) ; ./res/plugins/grapple.nvim/fnl/grapple
                 (vim.fs.dirname) ; ./res/plugins/grapple.nvim/fnl
                 (vim.fs.dirname) ; ./res/plugins/grapple.nvim
                 (vim.fs.dirname) ; ./res/plugins
                 (vim.fs.dirname) ; ./res
                 (vim.fs.dirname))
        script (vim.fs.joinpath root "lib" "cli.janet")
        pid (vim.fn.jobstart ["janet" script "--host" host "--port" port] {:detach true})]
    (n.assoc (state.get) :server-pid pid)
    (log.append :info ["Server started"])))

(fn with-conn-or-warn [f opts]
  (let [conn (state.get :conn)]
    (if conn
      (f conn)
      (log.append :info ["No connection"]))))

(fn connected? []
  (if (state.get :conn)
    true
    false))

(fn display-conn-status [status]
  (with-conn-or-warn
    (fn [conn] )))

(fn disconnect []
  (with-conn-or-warn
    (fn [conn]
      (request.sess-end conn nil)
      (conn.destroy)
      (display-conn-status :disconnected)
      (n.assoc (state.get) :conn nil))))

(fn stop-server []
  (let [pid (state.get :server-pid)]
    (when pid
      (disconnect)
      (vim.fn.jobstop pid)
      (n.assoc (state.get) :server-pid nil)
      (log.append :info ["Server stopped"]))))

(fn connect [opts]
  (let [buf (log.buf)
        opts (or opts {})
        host (or opts.host (config.get-in [:client :janet :mrepl :connection :default_host]))
        port (or opts.port (config.get-in [:client :janet :mrepl :connection :default_port]))
        lang (config.get-in [:client :janet :mrepl :connection :lang])
        auto-start? (not opts.no-auto-start?)]
    ; TODO: don't disconnect
    (when (state.get :conn)
      (disconnect))
    (local conn
      (remote.connect
        {:host host
         :port port
         :lang lang
         ; on-message handler
         :on-message
         handler.handle-message
         ; on-failure handler
         :on-failure
         (fn [err]
           (if (and auto-start? (not opts.retry?))
             (do
               (start-server opts)
               (vim.defer_fn #(connect (n.assoc opts :retry? true)) 1000))
             (do
               (display-conn-status err)
               (disconnect))))
         ; on-success handler
         :on-success
         (fn []
           (n.assoc (state.get) :conn conn)
           (display-conn-status :connected)
           (request.sess-new conn opts))
         ; on-error handler
         :on-error
         (fn [err]
           (if err
             (display-conn-status err)
             (disconnect)))}))))

(fn try-ensure-conn []
  (when (not (connected?))
    (connect {:silent? true})))

(fn eval-str [opts]
  (try-ensure-conn)
  (request.env-eval (state.get :conn) opts))

(fn eval-file [opts]
  (try-ensure-conn)
  (request.env-load (state.get :conn) opts))

(fn doc-str [opts]
  (try-ensure-conn)
  (request.env-doc (state.get :conn) opts))

(fn def-str [opts]
  (try-ensure-conn)
  (request.env-doc (state.get :conn) opts))

(fn on-filetype []
  (mapping.buf
    :JanetDisconnect
    (config.get-in [:client :janet :mrepl :mapping :disconnect])
    disconnect
    {:desc "Disconnect from the REPL"})
  (mapping.buf
    :JanetConnect
    (config.get-in [:client :janet :mrepl :mapping :connect])
    #(connect)
    {:desc "Connect to a REPL"})
  (mapping.buf
    :JanetStop
    (config.get-in [:client :janet :mrepl :mapping :stop-server])
    stop-server
    {:desc "Stop the Grapple server"}))

(fn on-load []
  (connect {}))

(fn on-exit []
  (disconnect))

(fn modify-client-exec-fn-opts [action f-name opts]
  (if
    (= "doc" action)
    (n.assoc opts :passive? true)
    (= "eval" action)
    (n.assoc opts :passive? true)))

{: buf-suffix
 : comment-node?
 : comment-prefix
 : start-server
 : stop-server
 : connect
 : disconnect
 : def-str
 : doc-str
 : eval-file
 : eval-str
 : form-node?
 : modify-client-exec-fn-opts
 : on-exit
 : on-filetype
 : on-load}

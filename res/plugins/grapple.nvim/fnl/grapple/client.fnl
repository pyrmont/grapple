(local {: autoload} (require :conjure.nfnl.module))
(local config (autoload :conjure.config))
(local handler (autoload :grapple.client.handler))
(local log (autoload :grapple.client.log))
(local mapping (autoload :conjure.mapping))
(local n (autoload :conjure.nfnl.core))
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
                   :lang "net.inqk/janet-1.0"
                   :auto-repl {:enabled true}}}}}})

(when (config.get-in [:mapping :enable_defaults])
  (config.merge
    {:client
     {:janet
      {:mrepl
       {:mapping {:connect "cc"
                  :disconnect "cd"
                  :start-server "cs"
                  :stop-server "cS"}}}}}))

(fn process-alive? [job-id]
  "Check if a job is still running"
  (let [result (vim.fn.jobwait [job-id] 0)]
    ; jobwait returns [-1] if job is still running, [exit-code] if done
    (= -1 (. result 1))))

(fn generate-token []
  "Generate a cryptographically random token using /dev/urandom"
  (let [f (io.open "/dev/urandom" "rb")
        bytes (f:read 16)  ; 16 bytes = 128 bits
        _ (f:close)
        hex-chars "0123456789abcdef"
        token (n.reduce
                (fn [acc byte]
                  (let [b (string.byte byte)
                        high (bit.rshift b 4)
                        low (bit.band b 0x0F)]
                    (.. acc
                        (string.sub hex-chars (+ high 1) (+ high 1))
                        (string.sub hex-chars (+ low 1) (+ low 1)))))
                ""
                (vim.split bytes "" true))]
    token))

(fn wait-for-server-ready [on-ready on-timeout]
  "Poll until server is ready, then call on-ready. Calls on-timeout if max attempts exceeded."
  (fn poll [attempt]
    (if (state.get :server-ready)
      (on-ready)
      (if (< attempt 50)  ; Max 5 seconds (50 * 100ms)
        (vim.defer_fn #(poll (+ attempt 1)) 100)
        (on-timeout))))
  (poll 0))

(fn start-server [opts]
  (let [buf (log.buf)
        existing-pid (state.get :server-pid)]
    ; Check if server is already running
    (if (and existing-pid (process-alive? existing-pid))
      (log.append :info ["Server is already running"])
      (let [host (or opts.host (config.get-in [:client :janet :mrepl :connection :default_host]))
            initial-port (or opts.port (config.get-in [:client :janet :mrepl :connection :default_port]))
            max-attempts 5
            ; Generate auth token for this server instance
            token (generate-token)
            ; Allow override via GRAPPLE_PATH env var for testing
            grapple-path (or vim.env.GRAPPLE_PATH
                             (vim.fn.exepath "grapple"))
            ; Split command into array for jobstart
            base-cmd (vim.split grapple-path " ")]
        ; Store token in state for use during connection
        (n.assoc (state.get) :token token)
        ; Mark server as not ready while starting
        (n.assoc (state.get) :server-ready false)
        (log.append :info [(.. "Starting server on port " initial-port "...")])
        (fn try-port [attempt current-port]
          (if (>= attempt max-attempts)
            (log.append :error [(.. "Failed to start server after " max-attempts " attempts")])
            (let [full-cmd (vim.list_extend (vim.fn.copy base-cmd)
                                            ["--host" host
                                             "--port" (tostring current-port)
                                             "--token" token])
                  job-id (vim.fn.jobstart full-cmd)]
              ; Set PID immediately to prevent duplicate starts
              (n.assoc (state.get) :server-pid job-id)
              (n.assoc (state.get) :server-port (tostring current-port))
              ; Wait 1 second then check if job is alive
              (vim.defer_fn
                (fn []
                  (if (process-alive? job-id)
                    (do
                      (log.append :info [(.. "Server started successfully on port " current-port)])
                      ; Mark server as ready
                      (n.assoc (state.get) :server-ready true))
                    (do
                      ; Clear the PID if server failed to start
                      (n.assoc (state.get) :server-pid nil)
                      (log.append :info [(.. "Port " current-port " unavailable, trying " (+ current-port 1) "...")])
                      ; Use same token for all port attempts
                      (try-port (+ attempt 1) (+ current-port 1)))))
                1000))))
        (try-port 0 (tonumber initial-port))))))

(fn with-conn-or-warn [f opts]
  (let [conn (state.get :conn)]
    (if conn
      (f conn)
      (log.append :error ["Not connected to server"]))))

(fn connected? []
  (if (state.get :conn)
    true
    false))

(fn display-conn-status [status]
  (let [buf (log.buf)]
    (case status
      :connected nil
      :disconnected (log.append :info ["Disconnected from server"])
      ; Otherwise it's an error - check if it's a connection refused error
      _ (if (or (string.find (tostring status) "connection refused")
                (string.find (tostring status) "ECONNREFUSED"))
          (log.append :error ["No server running, start with <localleader>cs"])
          (log.append :error [(tostring status)])))))

(fn disconnect []
  (with-conn-or-warn
    (fn [conn]
      (request.sess-end conn nil)
      (conn.destroy)
      (n.assoc (state.get) :conn nil)
      (log.append :info ["Disconnected from server"]))))

(fn stop-server []
  (let [buf (log.buf)
        pid (state.get :server-pid)]
    (if pid
      (do
        (when (state.get :conn)
          (disconnect))
        (vim.fn.jobstop pid)
        (n.assoc (state.get) :server-pid nil)
        (n.assoc (state.get) :token nil)
        (log.append :info ["Server stopped"]))
      (log.append :info ["No server running"]))))

(fn connect [opts]
  (let [buf (log.buf)
        opts (or opts {})
        host (or opts.host (config.get-in [:client :janet :mrepl :connection :default_host]))
        port (or opts.port
                 (state.get :server-port)
                 (config.get-in [:client :janet :mrepl :connection :default_port]))
        lang (config.get-in [:client :janet :mrepl :connection :lang])
        auto-start? (if (n.nil? opts.no-auto-start?)
                      (config.get-in [:client :janet :mrepl :connection :auto-repl :enabled])
                      (not opts.no-auto-start?))]
    (log.append :info [(.. "Attempting to connect to " host ":" port "...")])
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
               (wait-for-server-ready
                 ; on-ready
                 #(connect (n.assoc opts :retry? true))
                 ; on-timeout
                 #(log.append :error ["Server failed to start in time"])))
             (display-conn-status err)))
         ; on-success handler
         :on-success
         (fn []
           (n.assoc (state.get) :conn conn)
           (display-conn-status :connected)
           (request.sess-new conn
             (n.assoc opts
               :on-auth-error
               (fn []
                 ; Clear invalid token
                 (n.assoc (state.get) :token nil)
                 ; Clean up the failed connection without logging
                 (let [old-conn (state.get :conn)]
                   (when old-conn
                     (old-conn.destroy)
                     (n.assoc (state.get) :conn nil)))
                 ; Trigger auto-start if enabled
                 (if (and auto-start? (not opts.retry?))
                   (do
                     (log.append :info ["Authentication failed, starting new server..."])
                     ; Start server on next port since current port has a server with different token
                     (start-server (n.assoc opts :port (tostring (+ (tonumber port) 1))))
                     (wait-for-server-ready
                       ; on-ready
                       #(connect (n.assoc opts :retry? true))
                       ; on-timeout
                       #(log.append :error ["Server failed to start in time"])))
                   (log.append :error ["Authentication failed"]))))))
         ; on-error handler
         :on-error
         (fn [err]
           (if err
             (display-conn-status err)
             (disconnect)))}))))

(fn eval-str [opts]
  (with-conn-or-warn
    (fn [conn]
      (request.env-eval conn opts))
    opts))

(fn eval-file [opts]
  (with-conn-or-warn
    (fn [conn]
      (request.env-load conn opts))
    opts))

(fn doc-str [opts]
  (with-conn-or-warn
    (fn [conn]
      (request.env-doc conn opts))
    opts))

(fn def-str [opts]
  (with-conn-or-warn
    (fn [conn]
      (request.env-doc conn opts))
    opts))

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
    :JanetStart
    (config.get-in [:client :janet :mrepl :mapping :start-server])
    #(start-server {})
    {:desc "Start the Grapple server"})
  (mapping.buf
    :JanetStop
    (config.get-in [:client :janet :mrepl :mapping :stop-server])
    stop-server
    {:desc "Stop the Grapple server"}))

(fn on-load []
  ; Auto-connect disabled - use <localleader>cc to connect manually
  nil)

(fn on-exit []
  (disconnect))

(fn modify-client-exec-fn-opts [action f-name opts]
  (if
    (= "doc" action)
    (n.assoc opts :passive? true)
    (= "eval" action)
    (n.assoc opts :passive? true))
  (if (and opts.on-result opts.suppress-hud?)
    (let [on-result opts.on-result]
      (n.assoc opts :on-result (fn [result]
                                 (on-result (.. "=> " result)))))
    opts))

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

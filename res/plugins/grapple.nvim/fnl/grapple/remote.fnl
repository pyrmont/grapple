(local {: autoload} (require :nfnl.module))
(local a (autoload :conjure.aniseed.core))
(local client (autoload :conjure.client))
(local log (autoload :conjure.log))
(local net (autoload :conjure.net))
(local trn (autoload :grapple.transport))
(local uuid (autoload :conjure.uuid))

(fn connect [opts]
  "Connects to a remote mrepl server.
  * opts.host: The host string.
  * opts.port: Port as a string.
  * opts.on-failure: Function to call after a failed connection with the error.
  * opts.on-success: Function to call on a successful connection.
  * opts.on-error: Function to call when we receive an error (passed as argument) or a nil response.
  Returns a connection table containing a `send` `destroy` function."

  (var conn
    {:decode (trn.make-decode)
     :lang opts.lang
     :msgs {}
     :queue []
     :session nil})

  (fn send [msg action]
    (let [id (uuid.v4)]
      (a.assoc msg :id id :lang conn.lang)
      (when conn.session
        (a.assoc msg :sess conn.session))
      (a.assoc-in conn [:msgs id] {:msg msg :action action})
      (log.dbg "send" msg)
      (conn.sock:write (trn.encode msg))))

  (fn process-message [err chunk]
    (if (or err (not chunk))
      (opts.on-error err)
      (->> (conn.decode chunk)
           (a.run!
             (fn [msg]
               (log.dbg "receive" msg)
               (let [id msg.req
                     action (a.get-in conn [:msgs id :action])]
                 (opts.on-message msg action)))))))

  (fn process-queue []
    (set conn.awaiting-process? false)
    (when (not (a.empty? conn.queue))
      (let [msgs conn.queue]
        (set conn.queue [])
        (a.run!
          (fn [args]
            (process-message (unpack args)))
          msgs))))

  (fn enqueue-message [...]
    (table.insert conn.queue [...])
    (when (not conn.awaiting-process?)
      (set conn.awaiting-process? true)
      (client.schedule process-queue)))

  (fn handle-connect []
    (client.schedule-wrap
      (fn [err]
        (log.dbg "handle-connect" err)
        (if err
          (opts.on-failure err)
          (do
            (opts.on-success)
            (conn.sock:read_start (client.wrap enqueue-message)))))))

  (set conn
       (a.merge
         conn
         {:send send}
         (net.connect
           {:host opts.host
            :port opts.port
            :cb (handle-connect)})))

  conn)

;; Example:
; (def c (connect
;          {:host "127.0.0.1"
;           :port "9365"
;           :on-failure (fn [err] (a.println "oh no" err))
;           :on-success (fn [] (a.println "Yay!"))
;           :on-error (fn [err] (a.println "uh oh :(" err))}))
; (send c "{:hello :world}" a.println)
; (c.destroy)

{: connect}

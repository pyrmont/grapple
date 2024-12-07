(import ./utilities :as u)
(import ./handler :as h)
(import ./transport :as t)


(def default-host "0.0.0.0")
(def default-port 3737)


(defn- make-default-handler [sessions]
  (fn :handler [conn]
    (u/log "Connection opened")
    (def recv (t/make-recv conn))
    (def send (t/make-send conn))
    (forever
      (def req (recv))
      (xprintf stdout "woo")
      (u/log req)
      (if (nil? req) (break))
      (h/handle req sessions send))
    (u/log "Connection closed")))


(defn start [&named host port handler]
  (def sessions @{:count 0 :clients @{}})

  (default host default-host)
  (default port default-port)
  (default handler (make-default-handler sessions))

  (u/log (string "Server starting on port " port "..."))
  (def s (net/listen host port))
  (ev/go
    (fn :server []
      (try
        (net/accept-loop s handler)
        ([e fib]
         (if (= "stream is closed" e) # TODO: reconsider this
           (break)
           (propagate e fib))))))
  s)


(defn stop [s]
  (u/log "Server stopping...")
  (:close s))


(defn main [& args]
  (def host (when (> (length args) 1) (args 1)))
  (def port (when (> (length args) 2) (args 2)))
  (def log-level (if (> (length args) 3) :debug :normal))
  (setdyn :grapple/log-level log-level)
  (def s (start :host host :port port)))

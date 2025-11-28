(import ./utilities :as u)
(import ./handler :as h)
(import ./transport :as t)

(def default-host "127.0.0.1")
(def default-port 3737)

(defn- make-default-handler [sessions log-level]
  (fn :handler [conn]
    (setdyn :grapple/log-level log-level)
    (u/log "Connection opened")
    (def recv (t/make-recv conn))
    (def buf @"")
    (def sendb (t/make-send buf))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (h/handle req sessions sendb)
      (:write conn buf)
      (buffer/clear buf))
    (u/log "Connection closed")))

(defn start [&named host port handler log-level]
  (def sessions @{:count 0 :clients @{}})
  (default host default-host)
  (default port default-port)
  (default log-level :normal)
  (default handler (make-default-handler sessions log-level))
  (setdyn :grapple/log-level log-level)
  (u/log (string "Server starting at " host " on port " port "..."))
  (def server (net/listen host port))
  (ev/go
    (fn :server []
      (try
        (net/accept-loop server handler)
        ([e fib]
         (if (= "stream is closed" e) # TODO: reconsider this
           (break)
           (propagate e fib))))))
  server)

(defn stop [s]
  (u/log "Server stopping...")
  (:close s))

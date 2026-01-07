(import ./utilities :as u)
(import ./handler :as h)
(import ./transport :as t)

(def default-host "127.0.0.1")
(def default-port 3737)

(defn- check-port [s]
  (-> (net/localname s) (get 1)))

(defn- make-default-handler [sessions log-level]
  (fn :handler [conn]
    (u/set-log-level log-level)
    (u/log "Connection opened")
    (def recv (t/make-recv conn))
    (def f (ev/to-file conn))
    (def send (t/make-send f))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (h/handle req sessions send))
    (u/log "Connection closed")))

(defn start [&named host port handler log-level token]
  (def sessions @{:count 0 :clients @{} :token token})
  (default host default-host)
  (default port default-port)
  (default log-level :normal)
  (default handler (make-default-handler sessions log-level))
  (u/set-log-level log-level)
  (when token
    (u/log "Authentication required for connections" :debug))
  (def server (net/listen host port :stream true))
  (def used-port (if (zero? port) (check-port server) port))
  (u/log (string "Server started at " host " on port " used-port "..."))
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

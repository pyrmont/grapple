(import ./handler :as h)
(import ./transport :as t)


(def default-host "0.0.0.0")
(def default-port 3737)


(defn- make-default-handler [quiet?]
  (fn :handler [conn]
    (unless quiet?
      (print "Connection opened"))
    (def recv (t/make-recv conn))
    (def send (t/make-send conn))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (h/handle req send))
    (unless quiet?
      (print "Connection closed"))))


(defn start [&named host port handler quiet?]
  (default host default-host)
  (default port default-port)
  (default handler (make-default-handler quiet?))

  (unless quiet?
    (print "Server starting on port " port "..."))
  (def s (net/listen host port))
  (ev/go
    (fn :server []
      (protect (net/accept-loop s handler))))
  s)


(defn stop [s &named quiet?]
  (unless quiet?
    (print "Server stopping..."))
  (:close s)
  (h/reset))


(defn main [& args]
  (def host (when (> (length args) 1) (args 1)))
  (def port (when (> (length args) 2) (args 2)))
  (def s (start :host host :port port)))

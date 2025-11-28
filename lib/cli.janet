(import ../deps/argy-bargy/argy-bargy :as argy)
(import ./server :as server)

(def config
  ```
  The configuration for Argy-Bargy
  ```
  {:rules ["--host"        {:kind    :single
                            :short   "a"
                            :default "127.0.0.1"
                            :help    "IP address to bind to as the host."}
           "--port"        {:kind    :single
                            :short   "p"
                            :default 3737
                            :help    "TCP port to bind to as the host."}
           "--logging"     {:kind    :single
                            :short   "l"
                            :proxy   "level"
                            :default :normal
                            :value   (fn [l] (if (case l "normal" l "debug" l "off" l) (keyword l)))
                            :help    `Logging level to use, either "normal", "debug" or "off".`}
           "-------------------------------------------"]
   :info {:about "An mREPL server for Janet."}})

(defn run
  []
  (def parsed (argy/parse-args "grapple" config))
  (def err (parsed :err))
  (def help (parsed :help))
  (def opts (parsed :opts))
  (cond
    (not (empty? help))
    (do
      (prin help)
      (os/exit (if (opts "help") 0 1)))
    (not (empty? err))
    (do
      (eprin err)
      (os/exit 1))
    # default
    (server/start :host (opts "host")
                  :port (opts "port")
                  :log-level (opts "logging"))))

# for testing in development
(defn- main [& args] (run))

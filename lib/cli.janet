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


(defn- args->opts
  ```
  Converts Argy-Bargy processed args into options for use with generate-doc
  ```
  [args]
  @{:host (get-in args [:opts "host"])
    :port (get-in args [:opts "port"])
    :log-level (get-in args [:opts "logging"])})


(defn run
  []
  (def parsed (argy/parse-args "grapple" config))
  (def err (parsed :err))
  (def help (parsed :help))

  (cond
    (not (empty? help))
    (do
      (prin help)
      (os/exit (if (get-in parsed [:opts "help"]) 0 1)))

    (not (empty? err))
    (do
      (eprin err)
      (os/exit 1))

    (do
      (def opts (args->opts parsed))
      (setdyn :grapple/log-level (opts :log-level))
      (server/start (opts :host) (opts :port)))))


# for testing in development
(defn- main [& args] (run))

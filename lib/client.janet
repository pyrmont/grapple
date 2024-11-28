(import ./transport :as t)
(import ./server :as s)


(defn connect [&named host port quiet?]
  (default host s/default-host)
  (default port s/default-port)
  (def [success? res] (protect (net/connect host port)))
  (if success?
    (let [conn res
          recv (t/make-recv conn)
          send (t/make-send conn)]
      [recv send conn])
    (do
      (unless quiet?
        (print res))
      [nil nil nil])))


(defn disconnect [conn]
  (net/close conn))

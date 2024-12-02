(import ./utilities :as u)
(import ./transport :as t)
(import ./server :as s)


(defn connect [&named host port]
  (default host s/default-host)
  (default port s/default-port)
  (def [ok? res] (protect (net/connect host port)))
  (if ok?
    (let [conn res
          recv (t/make-recv conn)
          send (t/make-send conn)]
      [recv send conn])
    (do
      (u/log res)
      [nil nil nil])))


(defn disconnect [conn]
  (net/close conn))

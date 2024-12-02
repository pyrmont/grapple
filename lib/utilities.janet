(def lang "net.inqk/janet/1.0")
(def proj "grapple/1.0.0-dev")
(def prot "mrepl/1")
(def ns "<mrepl>")


(def- log-levels {:normal 1 :debug 2})


(defn log [msg &opt msg-lvl]
  (default msg-lvl :normal)
  (def l-lvl (dyn :grapple/log-level))
  (when l-lvl
    (def msg-s (if (string? msg) msg (string/format "%q" msg)))
    (def msg-lvl-num (log-levels msg-lvl))
    (def l-lvl-num (log-levels l-lvl))
    (when (>= l-lvl-num msg-lvl-num)
      (if (= :debug l-lvl)
        (xprintf stdout "[DBG] %s" msg-s)
        (print msg-s)))))


(defn make-send-err [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :sender [msg &opt details]
    (def resp @{"tag" "err"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "msg" msg})
    (send (cond
            (nil? details)
            resp

            (dictionary? details)
            (merge-into resp details)

            (error "invalid argument: must be nil or dictionary")))))


(defn make-send-note [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :sender [msg &opt details]
    (def resp @{"tag" "note"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "msg" msg})
    (send (cond
            (nil? details)
            resp

            (dictionary? details)
            (merge-into resp details)

            (error "invalid argument: must be nil or dictionary")))))


(defn make-send-out [req send ch]
  (def {"op" op "id" id "sess" sess} req)
  (fn :sender [val]
    (send {"tag" "out"
           "op" op
           "lang" lang
           "req" id
           "sess" sess
           "ch" ch
           "val" val})))


(defn make-send-ret [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :sender [val &opt details]
    (def resp @{"tag" "ret"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "done" true
                "val" val})
    (send (cond
            (nil? details)
            resp

            (dictionary? details)
            (merge-into resp details)

            (error "invalid argument: must be nil or dictionary")))))

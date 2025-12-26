(def lang "net.inqk/janet-1.0")
(def proj ["grapple" "1.0.0-dev"])
(def prot ["mrepl" "1"])
(def ns "<mrepl>")

(def- log-levels {:off 0 :normal 1 :debug 2})

(defn log [msg &opt level io]
  (default level :normal)
  (def log-level (log-levels (dyn :grapple/log-level)))
  (when log-level
    (def msg-level (log-levels level))
    (def s (if (string? msg) msg (string/format "%q" msg)))
    (when (>= log-level msg-level)
      (def prefix
        (when (= log-level 2)
          (case io
            :in
            "[DBG] (in) "
            :out
            "[DBG] (out) "
            # default
            "[DBG] ")))
      (printf (string prefix "%s") s))))

(defn make-send-err [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :err-sender [val &opt details]
    (def resp @{"tag" "err"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-note [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :note-sender [val &opt details]
    (def resp @{"tag" "note"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-out [req send ch]
  (def {"op" op "id" id "sess" sess} req)
  (fn :out-sender [val]
    (send {"tag" "out"
           "op" op
           "lang" lang
           "req" id
           "sess" sess
           "ch" ch
           "val" val})))

(defn make-send-ret [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :ret-sender [val &opt details]
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
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn stack [f]
  (map (fn [fr] {:name (fr :name)
                 :path (fr :source)
                 :line (fr :source-line)
                 :col  (fr :source-column)})
       (debug/stack f)))

(def lang "net.inqk/janet")
(def err-sentinel @"")


(defn make-send-err [send req]
  (def {"op" op "id" id "sess" sess} req)
  (fn sender [msg &opt details]
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

            (error "invalid argument: must be nil or dictionary")))
    (error err-sentinel)))


(defn make-send-out [send req ch]
  (def {"op" op "id" id "sess" sess} req)
  (fn sender [x]
    (send {"tag" "out"
           "op" op
           "lang" lang
           "req" id
           "sess" sess
           "ch" ch
           "val" x})))

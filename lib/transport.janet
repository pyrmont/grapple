# This code assumes that messages received will not have a length
# exceeding 2^32 - 1. Is this a safe assumption?
(import ../deps/medea :as json)
(import ./utilities :as u)

(defn make-recv [stream]
  (def buf @"")
  (fn :receiver []
    (buffer/clear buf)
    (def [success? res] (protect (:read stream 4 buf)))
    (when (and success? (not= nil res))
      (if-not (= 4 (length buf))
        (error "failed to read message length"))
      (def [b0 b1 b2 b3] buf)
      (def len (+ b0 (* b1 0x100) (* b2 0x10000) (* b3 0x1000000)))
      (buffer/clear buf)
      (:read stream len buf)
      (if-not (= len (length buf))
        (error "failed to read message payload"))
      (def res (json/decode buf))
      (u/log res :debug :in)
      res)))

(defn make-send [stream]
  (def buf @"")
  (fn :sender [msg]
    (buffer/clear buf)
    (def payload (json/encode msg))
    (u/log msg :debug :out)
    (buffer/push-word buf (length payload))
    (buffer/push-string buf payload)
    (cond
      # stream is a buffer
      (buffer? stream)
      (buffer/push-string stream buf)
      # stream is a file
      (= :core/file (type stream))
      (do
        (file/write stream buf)
        (file/flush stream))
      # default
      (:write stream buf))))

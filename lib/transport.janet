# This code assumes that messages received will not have a length
# exceeding 2^32 - 1. Is this a safe assumption?
(import ../deps/medea/medea :as json)


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
      (json/decode buf))))


(defn make-send [stream]
  (def buf @"")
  (fn :sender [msg]
    (buffer/clear buf)
    (def payload (json/encode msg))
    (buffer/push-word buf (length payload))
    (buffer/push-string buf payload)
    (if (buffer? stream) # hack because of how suspension works inside print
      (buffer/push-string stream buf)
      (:write stream buf))))

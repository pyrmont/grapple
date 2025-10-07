(import /deps/testament :prefix "" :exit true)
(import ../deps/medea :as json)
(import ../lib/transport :as t)

(def msg {"tag" "a-tag"
          "val" "a-value"})

(deftest receive-succeed
  (def [r w] (os/pipe))
  (def payload (json/encode msg))
  (def buf @"")
  (buffer/push-word buf (length payload))
  (buffer/push-string buf payload)
  (:write w buf)
  (:close w)
  (def recv (t/make-recv r))
  (def actual (recv))
  (def expect {"tag" "a-tag" "val" "a-value"})
  (is (== expect actual)))

(deftest receive-fail-length
  (def [r w] (os/pipe))
  (def data "\x15\0")
  (:write w data)
  (:close w)
  (def recv (t/make-recv r))
  (assert-thrown-message "failed to read message length" (recv)))

(deftest receive-fail-payload
  (def [r w] (os/pipe))
  (def data "\x15\0\0\0")
  (:write w data)
  (:close w)
  (def recv (t/make-recv r))
  (assert-thrown-message "failed to read message payload" (recv)))

(deftest send-succeed
  (def [r w] (os/pipe))
  (def send (t/make-send w))
  (send msg)
  (:close w)
  (def actual (:read r :all))
  (def payload (json/encode msg))
  (def expect (-> @""
                  (buffer/push-word (length payload))
                  (buffer/push-string payload)))
  (is (== expect actual)))

(deftest send-fail
  (def [r w] (os/pipe))
  (def send (t/make-send w))
  (:close w)
  (assert-thrown-message "stream is closed" (send msg)))

(run-tests!)

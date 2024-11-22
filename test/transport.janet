(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/transport :as t)


(deftest receive-succeed
  (def [r w] (os/pipe))
  (def data "\x15\0\0\0{\"id\":1,\"tag\":\"done\"}")
  (:write w data)
  (:close w)
  (def recv (t/make-recv r))
  (def actual (recv))
  (def expect {"tag" "done" "id" 1})
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
  (def msg {"tag" "done" "id" 1})
  (def send (t/make-send w))
  (send msg)
  (:close w)
  (def actual (:read r :all))
  # set up expected value
  (def payload "{\"id\":1,\"tag\":\"done\"}")
  (def expect (-> @""
                  (buffer/push-word (length payload))
                  (buffer/push-string payload)))
  (is (== expect actual)))


(deftest send-fail
  (def [r w] (os/pipe))
  (def msg {"tag" "done" "id" 1})
  (def send (t/make-send w))
  (:close w)
  (assert-thrown-message "stream is closed" (send msg)))


(run-tests!)

(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/transport :as t)
(import ../lib/server :as s)
(import ../lib/client :as c)


# Shared state between tests

(var server nil)
(var client nil)


# Teardown function

(defn teardown [t]
  (t)
  (if client
    (c/disconnect client))
  (if server
    (s/stop server :quiet? true)))


# Utility functions

(defn handshake [recv send]
  (def req {"lang" u/lang "id" "1" "op" "sess/new"})
  (send req))


(defn make-streams [conn]
  [(t/make-recv conn) (t/make-send conn)])


# Tests

(deftest server-up-down
  (def actual-1 @"")
  (def actual-2 @"")
  (with-dyns [:out actual-1 :err actual-2]
    (def server (s/start :quiet))
    (s/stop server))
  (def expect-1 "Server starting on port 3737...\nServer stopping...\n")
  (is (== expect-1 actual-1))
  (is (empty? actual-2)))


(deftest client-connect
  (defn handler [conn]
    (def [recv send] (make-streams conn))
    (def req (recv))
    (def {"id" req-id "sess" sess-id "op" op} req)
    (send {"tag" "ok"}))
  (set server (s/start :handler handler :quiet? true))
  (def [recv send conn] (c/connect :quiet? true))
  (is (and recv send conn))
  (send {"lang" u/lang "id" "1"})
  (def actual (recv))
  (def expect {"tag" "ok"})
  (is (== expect actual)))


(deftest client-echo
  (defn handler [conn]
    (def [recv send] (make-streams conn))
    (var n 0)
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (send req)))
  (set server (s/start :handler handler :quiet? true))
  (def [recv send conn] (c/connect :quiet? true))
  (is (and recv send conn))
  (set client conn)
  (each id [1 2 3 4 5]
    (def expect {"lang" u/lang "id" id})
    (send expect)
    (def actual (recv))
    (is (== expect actual))))


(use-fixtures :each teardown)
(run-tests!)

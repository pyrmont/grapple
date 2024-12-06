(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/transport :as t)
(import ../lib/handler :as h)
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
    (s/stop server)))


# Utility functions

(defn handshake [recv send]
  (def req {"lang" u/lang "id" "1" "op" "sess.new"})
  (send req))


(defn make-streams [conn]
  [(t/make-recv conn) (t/make-send conn)])


# Tests

(deftest server-up-down
  (def actual-1 @"")
  (def actual-2 @"")
  (with-dyns [:out actual-1 :err actual-2 :grapple/log-level :normal]
    (def server (s/start))
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
  (set server (s/start :handler handler))
  (def [recv send conn] (c/connect))
  (is (and recv send conn))
  (send {"lang" u/lang "id" "1"})
  (def actual (recv))
  (def expect {"tag" "ok"})
  (is (== expect actual)))


(deftest client-echo
  (defn handler [conn]
    (def [recv send] (make-streams conn))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (send req)))
  (set server (s/start :handler handler))
  (def [recv send conn] (c/connect))
  (is (and recv send conn))
  (set client conn)
  (each id [1 2 3 4 5]
    (def expect {"lang" u/lang "id" id})
    (send expect)
    (def actual (recv))
    (is (== expect actual))))


(deftest client-complex
  (def sessions @{:count 0 :clients @{}})
  (defn handler [conn]
    (def [recv send] (make-streams conn))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (h/handle req sessions send)))
  (set server (s/start :handler handler))
  (def [recv send conn] (c/connect))
  (is (and recv send conn))
  (set client conn)
  (send {"op" "sess.new"
         "lang" u/lang
         "id" "1"})
  (def actual-1 (recv))
  (def expect-1 {"tag" "ret"
                 "op" "sess.new"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true
                 "val" {"prot" u/prot
                        "lang" u/lang
                        "impl" (string "janet/" janet/version)
                        "os" (string (os/which))
                        "arch" (string (os/arch))
                        "serv" u/proj}})
  (is (== expect-1 actual-1))
  (send {"op" "sess.list"
         "lang" u/lang
         "id" "1"
         "sess" "1"})
  (def actual-2 (recv))
  (def expect-2 {"tag" "ret"
                 "op" "sess.list"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true
                 "val" ["1"]})
  (is (== expect-2 actual-2))
  (send {"op" "env.eval"
         "lang" u/lang
         "id" "1"
         "sess" "1"
         "ns" "<mrepl>"
         "code" "(def a 5)"})
  (def actual-3 (recv))
  (def expect-3 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "5"
                 "janet/path" "<mrepl>"
                 "janet/line" 1
                 "janet/col" 1})
  (is (== expect-3 actual-3))
  (def actual-4 (recv))
  (def expect-4 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true})
  (is (== expect-4 actual-4))
  (send {"op" "env.eval"
         "lang" u/lang
         "id" "1"
         "sess" "1"
         "ns" "<mrepl>"
         "code" "(inc a)"})
  (def actual-5 (recv))
  (def expect-5 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "6"
                 "janet/path" "<mrepl>"
                 "janet/line" 1
                 "janet/col" 1})
  (is (== expect-5 actual-5))
  (def actual-6 (recv))
  (def expect-6 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true})
  (is (== expect-6 actual-6))
  (def actual-7 @"")
  (with-dyns [:out actual-7 :grapple/log-level :normal]
    (c/disconnect conn)
    (set client nil)
    (s/stop server)
    (set server nil))
  (def expect-7 "Server stopping...\n")
  (is (== expect-7 actual-7)))


(use-fixtures :each teardown)
(run-tests!)

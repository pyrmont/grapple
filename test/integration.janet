(import /deps/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/transport :as t)
(import ../lib/handler :as h)
(import ../lib/server :as s)
(import ../lib/client :as c)

# Shared state between tests

(var server nil)
(var client nil)

# Teardown function

(defn teardown []
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
  (with-dyns [:out actual-1
              :err actual-2]
    (def server (s/start :log-level :normal))
    (s/stop server))
  (def expect-1 "Server starting at 127.0.0.1 on port 3737...\nServer stopping...\n")
  (is (== expect-1 actual-1))
  (is (empty? actual-2))
  (teardown))

(deftest client-connect
  (defn handler [conn]
    (def [recv send] (make-streams conn))
    (def req (recv))
    (def {"id" req-id "sess" sess-id "op" op} req)
    (send {"tag" "ok"}))
  (set server (s/start :handler handler :log-level :none))
  (def [recv send conn] (c/connect))
  (is (and recv send conn))
  (send {"lang" u/lang "id" "1"})
  (def actual (recv))
  (def expect {"tag" "ok"})
  (is (== expect actual))
  (teardown))

(deftest client-echo
  (defn handler [conn]
    (def [recv send] (make-streams conn))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (send req)))
  (set server (s/start :handler handler :log-level :none))
  (def [recv send conn] (c/connect))
  (is (and recv send conn))
  (set client conn)
  (each id [1 2 3 4 5]
    (def expect {"lang" u/lang "id" id})
    (send expect)
    (def actual (recv))
    (is (== expect actual)))
  (teardown))

(deftest client-complex
  (def sessions @{:count 0 :clients @{}})
  (defn handler [conn]
    (def [recv _] (make-streams conn))
    (def buf @"")
    (def sendb (t/make-send buf))
    (forever
      (def req (recv))
      (if (nil? req) (break))
      (h/handle req sessions sendb)
      (:write conn buf)
      (buffer/clear buf)))
  (set server (s/start :handler handler :log-level :none))
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
                 "janet/arch" (string (os/arch))
                 "janet/impl" ["janet" janet/version]
                 "janet/os" (string (os/which))
                 "janet/prot" u/prot
                 "janet/serv" u/proj})
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
  (send {"op" "env.eval"
         "lang" u/lang
         "id" "1"
         "sess" "1"
         "ns" "<mrepl>"
         "code" "(defn x [] (print :foo) :bar) (x)"})
  (def actual-7 (recv))
  (def expect-7 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "<function x>"
                 "janet/path" "<mrepl>"
                 "janet/line" 1
                 "janet/col" 1})
  (is (== expect-7 actual-7))
  (def actual-8 (recv))
  (def expect-8 {"tag" "out"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "ch" "out"
                 "val" "foo\n"})
  (is (== expect-8 actual-8))
  (def actual-9 (recv))
  (def expect-9 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" ":bar"
                 "janet/path" "<mrepl>"
                 "janet/line" 1
                 "janet/col" 31})
  (is (== expect-9 actual-9))
  (def actual-10 (recv))
  (def expect-10 {"tag" "ret"
                  "op" "env.eval"
                  "lang" u/lang
                  "req" "1"
                  "sess" "1"
                  "done" true})
  (is (== expect-10 actual-10))
  (teardown))

(run-tests!)

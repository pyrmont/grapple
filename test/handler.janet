(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/handler :as h)


# Fixtures

(def sessions @{})


(defn setup [t]
  (put sessions :count 1)
  (put sessions :clients @{"1" true})
  (t))


(defn teardown [t]
  (t)
  (table/clear sessions))


# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/take chan)) (fn [v] (ev/give chan v)) chan])


# Tests

(deftest confirm
  (def [recv send chan] (make-stream))
  (defn send-err [msg]
    (send {"tag" "err"
           "msg" msg}))
  (h/confirm {} ["id" "sess"] send-err)
  (def actual (recv))
  (def expect {"tag" "err"
               "msg" "request missing key \"id\""})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest sess-new
  (def [recv send chan] (make-stream))
  (h/handle {"op" "sess/new"
             "lang" u/lang
             "id" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/new"
               "lang" u/lang
               "req" "1"
               "sess" "2"
               "done" true
               "val" {"arch" (os/arch)
                      "impl" (string "janet/" janet/version)
                      "lang" u/lang
                      "os" (os/which)
                      "prot" u/prot
                      "serv" u/proj}})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest sess-end
  (def [recv send chan] (make-stream))
  (h/handle {"op" "sess/end"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/end"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "Session ended."})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest sess-list
  (def [recv send chan] (make-stream))
  (put (sessions :clients) "2" true)
  (h/handle {"op" "sess/list"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/list"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" @["1" "2"]})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest serv-info
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv/info"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/info"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" {"arch" (os/arch)
                      "impl" (string "janet/" janet/version)
                      "lang" u/lang
                      "os" (os/which)
                      "prot" u/prot
                      "serv" u/proj}})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest serv-stop
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv/stop"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/stop"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "Server shutting down..."})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest serv-relo
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv/relo"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/relo"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "Server reloading..."})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest env-eval
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env/eval"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "code" "(+ 1 2)"}
            sessions
            send)
  (def actual-1 (do (recv) (recv)))
  (def expect-1 {"tag" "ret"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true})
  (is (== expect-1 actual-1))
  (h/handle {"op" "env/eval"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "code" 5}
            sessions
            send)
  (def actual-2 (recv))
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" "code must be string"})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest env-load
  (def [recv send chan] (make-stream))
  (def path "./res/test/handler-env-load.janet")
  (h/handle {"op" "env/load"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" path}
            sessions
            send)
  (def actual-1 (do (recv) (recv) (recv)))
  (def expect-1 {"tag" "ret"
                 "op" "env/load"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true})
  (is (== expect-1 actual-1))
  (h/handle {"op" "env/load"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" "path/to/nowhere.txt"}
            sessions
            send)
  (def actual-2 (recv))
  (def expect-msg "request failed: could not open file path/to/nowhere.txt")
  (def expect-2 {"tag" "err"
                 "op" "env/load"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" expect-msg})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest env-doc
  (def [recv send chan] (make-stream))
  (def env @{'x @{:doc "The number five." :value 5}})
  (put module/cache u/ns env)
  (h/handle {"op" "env/doc"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "sym" "x"
             "janet/type" "symbol"}
            sessions
            send)
  (put module/cache u/ns nil)
  (def actual-1 (recv))
  (def expect-1 {"tag" "ret"
                 "op" "env/doc"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true
                 "val" "The number five."
                 "janet/type" :number})
  (is (== expect-1 actual-1))
  (h/handle {"op" "env/doc"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "sym" "y"
             "janet/type" "symbol"}
            sessions
            send)
  (def actual-2 (recv))
  (def expect-2 {"tag" "err"
                 "op" "env/doc"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" "symbol y not found"})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest env-cmpl
  (def [recv send chan] (make-stream))
  (def env @{'foo1 @{:value 1}
             'foo2 @{:value 2}})
  (put module/cache u/ns env)
  (h/handle {"op" "env/cmpl"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "sym" "foo"
             "janet/type" "symbol"}
            sessions
            send)
  (put module/cache u/ns nil)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env/cmpl"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" ["foo1" "foo2"]})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(use-fixtures :each setup teardown)
(run-tests!)

(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/handler :as h)


# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/take chan)) (fn [v] (ev/give chan v)) chan])


# Fixture Functions

(defn teardown [t]
  (t)
  (table/clear h/env)
  (table/clear h/sessions)
  (set h/sess-counter 0))


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


(deftest handle-sess-new
  (def [recv send chan] (make-stream))
  (put h/sessions "1" true)
  (set h/sess-counter 1)
  (h/handle {"op" "sess/new"
             "lang" u/lang
             "id" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/new"
               "lang" u/lang
               "req" "1"
               "sess" "2"
               "done" true
               "val" {"arch" (string (os/arch))
                      "impl" (string "janet/" janet/version)
                      "lang" u/lang
                      "os" (string (os/which))
                      "ver" "mrepl/1"}})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest handle-sess-end
  (def [recv send chan] (make-stream))
  (h/handle {"op" "sess/end"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
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


(deftest handle-sess-list
  (def [recv send chan] (make-stream))
  (put h/sessions "1" true)
  (put h/sessions "2" true)
  (h/handle {"op" "sess/list"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
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


(deftest handle-serv-info
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv/info"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/info"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" {"arch" (string (os/arch))
                      "impl" (string "janet/" janet/version)
                      "lang" u/lang
                      "os" (string (os/which))
                      "ver" "mrepl/1"}})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest handle-serv-stop
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv/stop"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
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


(deftest handle-serv-relo
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv/relo"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
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


(deftest handle-env-eval
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env/eval"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "done" true
             "code" "(+ 1 2)"}
            send)
  (def actual-1 (recv))
  (def actual-2 (recv))
  (def expect {"tag" "ret"
               "op" "env/eval"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" false
               "val" "3"
               "janet/path" :<mrepl>
               "janet/line" 1
               "janet/col" 1})
  (is (== expect actual-1))
  (is actual-2)
  (is (zero? (ev/count chan))))


(deftest handle-env-load
  (def [recv send chan] (make-stream))
  (def path "test/resources/handler-env-load.txt")
  (h/handle {"op" "env/load"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" path}
            send)
  (def actual-1 (recv))
  (def actual-2 (recv))
  (def actual-3 (recv))
  (def expect {"tag" "ret"
               "op" "env/load"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" false
               "val" "1"
               "janet/path" path
               "janet/line" 4
               "janet/col" 1})
  (is (== expect actual-2))
  (is actual-3)
  (is (zero? (ev/count chan))))


(deftest handle-env-doc
  (def [recv send chan] (make-stream))
  (put h/env 'x @{:doc "The number five." :value 5})
  (h/handle {"op" "env/doc"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "sym" 'x}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env/doc"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "The number five."
               "janet/type" "number"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))


(deftest handle-env-cmpl
  (def [recv send chan] (make-stream))
  (put h/env 'foo1 @{:value 1})
  (put h/env 'foo2 @{:value 2})
  (h/handle {"op" "env/cmpl"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "sym" "foo"
             "janet/type" "symbol"}
            send)
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


(use-fixtures :each teardown)

(run-tests!)

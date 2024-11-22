(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/handler :as h)


# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/take chan)) (fn [v] (ev/give chan v))])


# Fixture Functions

(defn teardown [t]
  (t)
  (table/clear h/env)
  (table/clear h/sessions)
  (set h/sess-counter 0))


# Tests

(deftest confirm
  (def [recv send] (make-stream))
  (defn send-err [&named to msg]
    (send {"tag" "err"
           "msg" msg}))
  (h/confirm {} :has ["id" "sess"] :else send-err)
  (def actual (recv))
  (def expect {"tag" "err"
               "msg" "request missing key \"id\""})
  (is (== expect actual)))


(deftest handle-sess-new
  (def [recv send] (make-stream))
  (put h/sessions "1" true)
  (set h/sess-counter 1)
  (h/handle {"op" "sess/new" "id" "1"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "2"
               "op" "sess/new"
               "val" {"arch" (string (os/arch))
                      "lang" (string "janet/" janet/version)
                      "os" (string (os/which))
                      "ver" "mrepl/1"}})
  (is (== expect actual)))


(deftest handle-sess-end
  (def [recv send] (make-stream))
  (h/handle {"op" "sess/end" "id" "1" "sess" "1"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "sess/end"
               "val" "Session ended."})
  (is (== expect actual)))


(deftest handle-sess-list
  (def [recv send] (make-stream))
  (put h/sessions "1" true)
  (put h/sessions "2" true)
  (h/handle {"op" "sess/list" "id" "1" "sess" "1"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "sess/list"
               "val" @["1" "2"]})
  (is (== expect actual)))


(deftest handle-serv-info
  (def [recv send] (make-stream))
  (h/handle {"op" "serv/info" "id" "1" "sess" "1"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "serv/info"
               "val" {"arch" (string (os/arch))
                      "lang" (string "janet/" janet/version)
                      "os" (string (os/which))
                      "ver" "mrepl/1"}})
  (is (== expect actual)))


(deftest handle-serv-stop
  (def [recv send] (make-stream))
  (h/handle {"op" "serv/stop" "id" "1" "sess" "1"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "serv/stop"
               "val" "Server shutting down..."})
  (is (== expect actual)))


(deftest handle-serv-relo
  (def [recv send] (make-stream))
  (h/handle {"op" "serv/relo" "id" "1" "sess" "1"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "serv/relo"
               "val" "Server reloading..."})
  (is (== expect actual)))


(deftest handle-env-eval
  (def [recv send] (make-stream))
  (h/handle {"op" "env/eval" "id" "1" "sess" "1" "code" "(+ 1 2)"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "env/eval"
               "val" "3"})
  (is (== expect actual)))


(deftest handle-env-load
  (def [recv send] (make-stream))
  (h/handle {"op" "env/load" "id" "1" "sess" "1" "path" "test/resources/handler-env-load.txt"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "env/load"
               "val" "<function add-1>"})
  (is (== expect actual)))


(deftest handle-env-doc
  (def [recv send] (make-stream))
  (put h/env 'x @{:doc "The number five." :value 5})
  (h/handle {"op" "env/doc" "id" "1" "sess" "1" "sym" "x"} send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "req" "1"
               "sess" "1"
               "op" "env/doc"
               "val" "\n\n    number\n\n    The number five.\n\n\n"})
  (is (== expect actual)))


(use-fixtures :each teardown)

(run-tests!)

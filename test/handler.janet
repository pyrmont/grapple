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
  (h/handle {"op" "sess/new"
             "lang" h/lang
             "id" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/new"
               "lang" h/lang
               "req" "1"
               "sess" "2"
               "val" {"arch" (string (os/arch))
                      "impl" (string "janet/" janet/version)
                      "lang" h/lang
                      "os" (string (os/which))
                      "ver" "mrepl/1"}})
  (is (== expect actual)))


(deftest handle-sess-end
  (def [recv send] (make-stream))
  (h/handle {"op" "sess/end"
             "lang" h/lang
             "id" "1"
             "sess" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/end"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" "Session ended."})
  (is (== expect actual)))


(deftest handle-sess-list
  (def [recv send] (make-stream))
  (put h/sessions "1" true)
  (put h/sessions "2" true)
  (h/handle {"op" "sess/list"
             "lang" h/lang
             "id" "1"
             "sess" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess/list"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" @["1" "2"]})
  (is (== expect actual)))


(deftest handle-serv-info
  (def [recv send] (make-stream))
  (h/handle {"op" "serv/info"
             "lang" h/lang
             "id" "1"
             "sess" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/info"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" {"arch" (string (os/arch))
                      "impl" (string "janet/" janet/version)
                      "lang" h/lang
                      "os" (string (os/which))
                      "ver" "mrepl/1"}})
  (is (== expect actual)))


(deftest handle-serv-stop
  (def [recv send] (make-stream))
  (h/handle {"op" "serv/stop"
             "lang" h/lang
             "id" "1"
             "sess" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/stop"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" "Server shutting down..."})
  (is (== expect actual)))


(deftest handle-serv-relo
  (def [recv send] (make-stream))
  (h/handle {"op" "serv/relo"
             "lang" h/lang
             "id" "1"
             "sess" "1"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv/relo"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" "Server reloading..."})
  (is (== expect actual)))


(deftest handle-env-eval
  (def [recv send] (make-stream))
  (h/handle {"op" "env/eval"
             "lang" h/lang
             "id" "1"
             "sess" "1"
             "code" "(+ 1 2)"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env/eval"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" "3"})
  (is (== expect actual)))


(deftest handle-env-load
  (def [recv send] (make-stream))
  (h/handle {"op" "env/load"
             "lang" h/lang
             "id" "1"
             "sess" "1"
             "path" "test/resources/handler-env-load.txt"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env/load"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" "<function add-1>"})
  (is (== expect actual)))


(deftest handle-env-doc
  (def [recv send] (make-stream))
  (put h/env 'x @{:doc "The number five." :value 5})
  (h/handle {"op" "env/doc"
             "lang" h/lang
             "id" "1"
             "sess" "1"
             "sym" "x"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env/doc"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" "The number five."
               "janet/type" "number"})
  (is (== expect actual)))


(deftest handle-env-cmpl
  (def [recv send] (make-stream))
  (put h/env 'foo1 @{:value 1})
  (put h/env 'foo2 @{:value 2})
  (h/handle {"op" "env/cmpl"
             "lang" h/lang
             "id" "1"
             "sess" "1"
             "sym" "foo"}
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env/cmpl"
               "lang" h/lang
               "req" "1"
               "sess" "1"
               "val" ['foo1 'foo2]})
  (is (== expect actual)))


(use-fixtures :each teardown)

(run-tests!)

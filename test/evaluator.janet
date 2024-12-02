(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/evaluator :as e)


# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/take chan))
   (fn [v] (ev/give chan v))
   chan])


# Generic eval request

(def req
  {"op" "env/eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})


# Tests

(deftest run-succeed-calculation
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(+ 1 2)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-2
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "3"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest run-succeed-output
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(print \"Hello world\")" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (is (== expect-2 actual-2))
  (def actual-3 (recv))
  (def expect-3
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "nil"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1})
  (is (== expect-3 actual-3))
  (is (zero? (ev/count chan))))


(deftest run-succeed-stdout
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(xprint stdout \"Hello world\")" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (is (== expect-2 actual-2))
  (def actual-3 (recv))
  (def expect-3
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "nil"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1})
  (is (== expect-3 actual-3))
  (is (zero? (ev/count chan))))


(deftest run-fail-parser
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(print \"Hello world\"" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "parse error: unexpected end of source, ( opened at line 1, column 1")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 20})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest run-fail-compiler-1
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(foo)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "compile error: unknown symbol foo")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest run-fail-compiler-2
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(defmacro foo [x] (x)) (foo 1)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-2 {"tag" "ret"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "<function foo>"
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1})
  (is (== expect-2 actual-2))
  (def actual-3 (recv))
  (def expect-msg "compile error: error: (macro) 1 called with 0 arguments, possibly expected 1")
  (def expect-3 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 24
                 "janet/stack" [{:col 19 :line 1 :name "foo" :path u/ns}]})
  (is (== expect-3 actual-3))
  (is (zero? (ev/count chan))))


(deftest run-fail-runtime
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(+ 1 nil)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "error: could not find method :+ for 1 or :r+ for nil")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1
                 "janet/stack" [{:col 1 :line 1 :name "thunk" :path u/ns}]})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest run-warn-compiler
  (def [recv send chan] (make-stream))
  (def env (e/new-env))
  (def actual-1
    (e/run "(def x :deprecated 1) (inc x)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-2 {"tag" "ret"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "1"
                 "janet/path" u/ns
                 "janet/col" 1
                 "janet/line" 1})
  (is (== expect-2 actual-2))
  (def actual-3 (recv))
  (def expect-3 {"tag" "note"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" "compile warning (normal): x is deprecated"
                 "janet/path" u/ns
                 "janet/col" 23
                 "janet/line" 1})
  (is (== expect-3 actual-3))
  (def actual-4 (recv))
  (def expect-4 {"tag" "ret"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "2"
                 "janet/path" u/ns
                 "janet/col" 23
                 "janet/line" 1})
  (is (== expect-4 actual-4))
  (is (zero? (ev/count chan))))


(run-tests!)

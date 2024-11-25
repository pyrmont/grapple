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
  (def env (make-env))
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
     "val" "3"})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))


(deftest run-succeed-output
  (def [recv send chan] (make-stream))
  (def env (make-env))
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
     "val" "nil"})
  (is (== expect-3 actual-3))
  (is (zero? (ev/count chan))))


(deftest run-fail-parser
  (def [recv send chan] (make-stream))
  (def env (make-env))
  (def actual-1
    (e/run "(print \"Hello world\"" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "parse error: unexpected end of source, ( opened at line 1, column 1")
  (def expect {"tag" "err"
               "op" "env/eval"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "msg" expect-msg
               "janet/path" :<mrepl>
               "janet/col" 20
               "janet/line" 1})
  (is (== expect actual-2))
  (is (zero? (ev/count chan))))


(deftest run-fail-compiler
  (def [recv send chan] (make-stream))
  (def env (make-env))
  (def actual-1
    (e/run "(foo)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "compile error: unknown symbol foo")
  (def expect {"tag" "err"
               "op" "env/eval"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "msg" expect-msg
               "janet/path" :<mrepl>
               "janet/col" 1
               "janet/line" 1})
  (is (== expect actual-2))
  (is (zero? (ev/count chan))))


(deftest run-fail-runtime
  (def [recv send chan] (make-stream))
  (def env (make-env))
  (def actual-1
    (e/run "(+ 1 nil)" :env env :send send :req req))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "error: could not find method :+ for 1 or :r+ for nil")
  (def expect {"tag" "err"
               "op" "env/eval"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "msg" expect-msg
               "janet/stack" (actual-2 "janet/stack")})
  (is (== expect actual-2))
  (is (zero? (ev/count chan))))


(run-tests!)

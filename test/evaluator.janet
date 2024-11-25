(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/handler :as h)
(import ../lib/evaluator :as e)


# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/take chan))
   (fn [v] (ev/give chan v))
   chan])


(defn make-sends [send req]
  [(u/make-send-ret send req)
   (u/make-send-out send req "out")
   (u/make-send-out send req "err")
   (u/make-send-err send req)])


# Generic eval request

(def req
  {"op" "env/eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})


# Tests

(deftest run-succeed-result
  (def [recv send chan] (make-stream))
  (def env (make-env))
  (def parser (parser/new))
  (def [send-ret send-out-1 send-out-2 send-err] (make-sends send req))
  (def actual-1
    (e/run "(+ 1 2)"
           :env env
           :parser parser
           :ret send-ret
           :out-1 send-out-1
           :out-2 send-out-2
           :err send-err))
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


(deftest run-succeed-print
  (def [recv send chan] (make-stream))
  (def env (make-env))
  (def parser (parser/new))
  (def [send-ret send-out-1 send-out-2 send-err] (make-sends send req))
  (def actual-1
    (e/run "(print \"Hello world\")"
           :env env
           :parser parser
           :ret send-ret
           :out-1 send-out-1
           :out-2 send-out-2
           :err send-err))
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


(deftest run-fail-incomplete
  (def [recv send chan] (make-stream))
  (def env (make-env))
  (def parser (parser/new))
  (def [send-ret send-out-1 send-out-2 send-err] (make-sends send req))
  (def actual-1
    (e/run "(print \"Hello world\""
             :env env
             :parser parser
             :ret send-ret
             :out-1 send-out-1
             :out-2 send-out-2
             :err send-err))
  (is (nil? actual-1))
  (def actual-2 (recv))
  (def expect-msg
    "parse error: unexpected end of source, ( opened at line 1, column 1")
  (def expect {"tag" "err"
               "op" "env/eval"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" false
               "msg" expect-msg
               "janet/path" :<mrepl>
               "janet/col" 20
               "janet/line" 1})
  (is (== expect actual-2))
  (is (zero? (ev/count chan))))


(run-tests!)

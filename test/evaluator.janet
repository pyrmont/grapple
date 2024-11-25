(import /deps/testament/src/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/handler :as h)
(import ../lib/evaluator :as e)


# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/take chan)) (fn [v] (ev/give chan v))])


(defn make-sends [send req]
  [(u/make-send-out send req "out")
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
  (def [recv send] (make-stream))
  (def env (make-env))
  (def parser (parser/new))
  (def [send-out-1 send-out-2 send-err] (make-sends send req))
  (def actual
    (e/run "(+ 1 2)"
           :env env
           :parser parser
           :out-1 send-out-1
           :out-2 send-out-2
           :err send-err))
  (def expect 3)
  (is (== expect actual)))


(deftest run-succeed-print
  (def [recv send] (make-stream))
  (def env (make-env))
  (def parser (parser/new))
  (def [send-out-1 send-out-2 send-err] (make-sends send req))
  (def actual-1
    (e/run "(print \"Hello world\")"
           :env env
           :parser parser
           :out-1 send-out-1
           :out-2 send-out-2
           :err send-err))
  (def expect-1 nil)
  (is (== expect-1 actual-1))
  (def actual-2 (recv))
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (is (== expect-2 actual-2)))


(deftest run-fail-incomplete
  (def [recv send] (make-stream))
  (def env (make-env))
  (def parser (parser/new))
  (def [send-out-1 send-out-2 send-err] (make-sends send req))
  (def actual-1
    (protect
      (e/run "(print \"Hello world\""
             :env env
             :parser parser
             :out-1 send-out-1
             :out-2 send-out-2
             :err send-err)))
  (def expect-1 [false u/err-sentinel])
  (is (== expect-1 actual-1))
  (def actual-2 (recv))
  (def expect-2-msg
    "<mrepl>:1:20: parse error: unexpected end of source, ( opened at line 1, column 1\n")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "msg" expect-2-msg})
  (is (== expect-2 actual-2)))


(run-tests!)

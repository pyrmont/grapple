(import /deps/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/evaluator :as e)

# Utility Functions

(defn make-sender [b]
  (fn :send [v]
    # use buffer becuase ev/give doesn't work in janet_call
    (buffer/push b (string/format "%q" v))))

# Helper to run eval in fiber (matching handler behavior)
(defn run-eval [code & args]
  (def fib (fiber/new (fn [] (e/run code ;args)) :dey))
  (def res (resume fib))
  [res fib])

# Generic eval request

(def req
  {"op" "env.eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})

# Tests

(deftest run-succeed-calculation
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(+ 1 2)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "ret"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "3"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false
     "janet/result" "3"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (is (not (parser/has-more p))))

(deftest run-succeed-output
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(print \"Hello world\")" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3
    {"tag" "ret"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "nil"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false
     "janet/result" "nil"})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-succeed-stdout
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(xprint stdout \"Hello world\")" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3
    {"tag" "ret"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "nil"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false
     "janet/result" "nil"})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-succeed-import-direct
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def path (dyn :current-file))
  (def actual-1
    (e/run "(import ../res/test/imported1)" :env env :send send :req req :path path :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Imported world\n"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3-val "@{_ @{:value <cycle 0>} imported1/x @{:private true}}")
  (def expect-3
    {"tag" "ret"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" expect-3-val
     "janet/path" path
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false
     "janet/result" {:type "table"
                     :count 2
                     :length 53
                     :kvs @["_"
                            {:type "table"
                             :count 1
                             :length 53
                             :kvs @[":value"
                                    {:type "circular"
                                     :to "table"}]}
                            "imported1/x"
                            {:type "table"
                             :count 1
                             :length 16
                             :kvs @[":private"
                                    "true"]}]}})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-succeed-import-transitive
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def path (dyn :current-file))
  (def actual-1
    (e/run "(import ../res/test/imported2)" :env env :send send :req req :path path :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Imported world\n"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3-val "@{_ @{:value <cycle 0>}}")
  (def expect-3
    {"tag" "ret"
     "op" "env.eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" expect-3-val
     "janet/path" path
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false
     "janet/result" {:type "table"
                     :count 1
                     :length 24
                     :kvs @["_"
                            {:type "table"
                             :count 1
                             :length 24
                             :kvs @[":value"
                                    {:type "circular"
                                     :to "table"}]}]}})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-fail-parser
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(print \"Hello world\"" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-msg
    "parse error: unexpected end of source, ( opened at line 1, column 1")
  (def expect-2 {"tag" "err"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 20})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (is (not (parser/has-more p))))

(deftest run-fail-compiler-1
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(foo)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-msg
    "compile error: unknown symbol foo")
  (def expect-2 {"tag" "err"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (is (not (parser/has-more p))))

(deftest run-fail-compiler-2
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(defmacro foo [x] (x)) (foo 1)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "<function foo>"
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1
     "janet/reeval?" false
     "janet/result" {:type "function" :value "<function foo>"}})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-msg "compile error: error: (macro) 1 called with 0 arguments, possibly expected 1")
  (def expect-3 {"tag" "err"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 24
                 "janet/stack" @[{:col 19 :line 1 :name "foo" :path u/ns
                                  :pc 0 :tail nil
                                  :function "<function foo>"
                                  :slots "@[1 nil]"
                                  :locals "@{x 1}"}]})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-fail-runtime
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(+ 1 nil)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-msg
    "error: could not find method :+ for 1 or :r+ for nil")
  (def expect-2 {"tag" "err"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1
                 "janet/stack" @[{:col 1 :line 1 :name "thunk" :path u/ns
                                  :pc 2 :tail true
                                  :function "<function thunk>"
                                  :slots "@[nil 1 nil]"
                                  :locals "nil"}]})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (is (not (parser/has-more p))))

(deftest run-warn-compiler
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def actual-1
    (e/run "(def x :deprecated 1) (inc x)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "1"
                 "janet/path" u/ns
                 "janet/col" 1
                 "janet/line" 1
                 "janet/reeval?" false
                 "janet/result" "1"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 {"tag" "note"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" "compile warning (normal): x is deprecated"
                 "janet/path" u/ns
                 "janet/col" 23
                 "janet/line" 1})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "2"
                 "janet/path" u/ns
                 "janet/col" 23
                 "janet/line" 1
                 "janet/reeval?" false
                 "janet/result" "2"})
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (is (not (parser/has-more p))))

# Helper to get binding value from environment

(defn get-value [env sym]
  (def binding (get env sym))
  (if-let [ref (get binding :ref)]
    (get ref 0)
    (get binding :value)))

(run-tests!)

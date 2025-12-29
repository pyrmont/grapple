(import /deps/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/evaluator :as e)

# Utility Functions

(defn make-sender [b]
  (fn :send [v]
    # use buffer becuase ev/give doesn't work in janet_call
    (buffer/push b (string/format "%q" v))))

# Generic eval request

(def req
  {"op" "env/eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})

# Test session
(def sess @{:dep-graph @{}})

# Tests

(deftest run-succeed-calculation
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def actual-1
    (e/run "(+ 1 2)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
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
     "janet/col" 1
     "janet/reeval?" false})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (is (not (parser/has-more p))))

(deftest run-succeed-output
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def actual-1
    (e/run "(print \"Hello world\")" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
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
     "janet/col" 1
     "janet/reeval?" false})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-succeed-stdout
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def actual-1
    (e/run "(xprint stdout \"Hello world\")" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "ch" "out"
     "val" "Hello world\n"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
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
     "janet/col" 1
     "janet/reeval?" false})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-succeed-import-direct
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def path (dyn :current-file))
  (def actual-1
    (e/run "(import ../res/test/imported1)" :env env :send send :req req :path path :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
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
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" expect-3-val
     "janet/path" path
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-succeed-import-transitive
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def path (dyn :current-file))
  (def actual-1
    (e/run "(import ../res/test/imported2)" :env env :send send :req req :path path :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2
    {"tag" "out"
     "op" "env/eval"
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
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" expect-3-val
     "janet/path" path
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-fail-parser
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def actual-1
    (e/run "(print \"Hello world\"" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-msg
    "parse error: unexpected end of source, ( opened at line 1, column 1")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
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
  (def actual-1
    (e/run "(foo)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-msg
    "compile error: unknown symbol foo")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
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
  (def actual-1
    (e/run "(defmacro foo [x] (x)) (foo 1)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2 {"tag" "ret"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "<function foo>"
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1
     "janet/reeval?" false})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-msg "compile error: error: (macro) 1 called with 0 arguments, possibly expected 1")
  (def expect-3 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 24
                 "janet/stack" [{:col 19 :line 1 :name "foo" :path u/ns}]})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest run-fail-runtime
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def actual-1
    (e/run "(+ 1 nil)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-msg
    "error: could not find method :+ for 1 or :r+ for nil")
  (def expect-2 {"tag" "err"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" u/ns
                 "janet/line" 1
                 "janet/col" 1
                 "janet/stack" [{:col 1 :line 1 :name "thunk" :path u/ns}]})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (is (not (parser/has-more p))))

(deftest run-warn-compiler
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def actual-1
    (e/run "(def x :deprecated 1) (inc x)" :env env :send send :req req :sess sess))
  (is (nil? actual-1))
  (parser/consume p outb)
  (def expect-2 {"tag" "ret"
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "1"
                 "janet/path" u/ns
                 "janet/col" 1
                 "janet/line" 1
                 "janet/reeval?" false})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 {"tag" "note"
                 "op" "env/eval"
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
                 "op" "env/eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "2"
                 "janet/path" u/ns
                 "janet/col" 23
                 "janet/line" 1
                 "janet/reeval?" false})
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (is (not (parser/has-more p))))

# Helper to get binding value from environment

(defn get-value [env sym]
  (def binding (get env sym))
  (if-let [ref (get binding :ref)]
    (get ref 0)
    (get binding :value)))

# Dependency tracking tests

(deftest deps-simple-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define x and y where y depends on x
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y (+ x 5))" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'x)))
  (is (= 15 (get-value env 'y)))
  # Redefine x, y should auto-update
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'x)))
  (is (= 25 (get-value env 'y))))

(deftest deps-var-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define var a and b where b depends on a
  (e/run "(var a 10)" :env env :send send :req req :sess sess)
  (e/run "(def b (+ a 5))" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'a)))
  (is (= 15 (get-value env 'b)))
  # Redefine a, b should auto-update
  (buffer/clear outb)
  (e/run "(var a 20)" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'a)))
  (is (= 25 (get-value env 'b))))

(deftest deps-complex-expressions
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test nested function calls
  (e/run "(def x 5)" :env env :send send :req req :sess sess)
  (e/run "(def y 10)" :env env :send send :req req :sess sess)
  (e/run "(def z (+ (* x 2) y))" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'z)))
  # Test let bindings within defs
  (e/run "(def result1 (let [temp (+ x 1)] (* temp 2)))" :env env :send send :req req :sess sess)
  (is (= 12 (get-value env 'result1)))
  # Test conditionals
  (e/run "(def result2 (if (> x 3) (+ x y) y))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result2)))
  # Test do blocks
  (e/run "(def result3 (do (+ x 1) (+ x y)))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result3)))
  # Redefine x, all dependents should update
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'x)))
  (is (= 50 (get-value env 'z)))
  (is (= 42 (get-value env 'result1)))
  (is (= 30 (get-value env 'result2)))
  (is (= 30 (get-value env 'result3)))
  # Redefine y, relevant dependents should update
  (buffer/clear outb)
  (e/run "(def y 100)" :env env :send send :req req :sess sess)
  (is (= 100 (get-value env 'y)))
  (is (= 140 (get-value env 'z)))
  (is (= 42 (get-value env 'result1)))  # Doesn't depend on y
  (is (= 120 (get-value env 'result2)))
  (is (= 120 (get-value env 'result3))))

(deftest deps-macro-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define a macro and use it
  (e/run "(defmacro double [x] ~(* 2 ,x))" :env env :send send :req req :sess sess)
  (e/run "(def y (double 5))" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'y)))
  # Redefine the macro, y should be re-evaluated with new macro
  (buffer/clear outb)
  (e/run "(defmacro double [x] ~(* 3 ,x))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'y)))
  # Test macro that references a value
  (e/run "(def multiplier 4)" :env env :send send :req req :sess sess)
  (e/run "(defmacro mult [x] ~(* multiplier ,x))" :env env :send send :req req :sess sess)
  (e/run "(def z (mult 5))" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'z)))
  # Redefine multiplier - this affects the macro expansion
  (buffer/clear outb)
  (e/run "(def multiplier 10)" :env env :send send :req req :sess sess)
  # z should update because mult (which depends on multiplier) was redefined
  (is (= 50 (get-value env 'z))))

(deftest deps-local-scope-shadowing
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define global x
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  # Define y with local x that shadows global - y should NOT depend on global x
  (e/run "(def y (let [x 20] x))" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'x)))
  (is (= 20 (get-value env 'y)))
  # Redefine global x - y should NOT update
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  (is (= 100 (get-value env 'x)))
  (is (= 20 (get-value env 'y)))
  # Test let with outer reference (no shadowing)
  (e/run "(def z (let [a x] (+ a 5)))" :env env :send send :req req :sess sess)
  (is (= 105 (get-value env 'z)))  # a=100 (from global x), result=105
  # Redefine x - z should update (let binds a to x)
  (e/run "(def x 50)" :env env :send send :req req :sess sess)
  (is (= 55 (get-value env 'z))))

(deftest deps-function-parameter-shadowing
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test 1: Simple parameter shadowing
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(defn f [x] x)" :env env :send send :req req :sess sess)
  (e/run "(def result1 (f 20))" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'result1)))
  # Redefine global x - f should NOT be re-evaluated
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  (e/run "(def result2 (f 30))" :env env :send send :req req :sess sess)
  (is (= 30 (get-value env 'result2)))
  # Test 2: Function that uses both parameter and global
  (e/run "(defn g [y] (+ x y))" :env env :send send :req req :sess sess)
  (e/run "(def result3 (g 5))" :env env :send send :req req :sess sess)
  (is (= 105 (get-value env 'result3)))  # x=100, y=5
  # Redefine x - g should be re-evaluated
  (e/run "(def x 50)" :env env :send send :req req :sess sess)
  (e/run "(def result4 (g 5))" :env env :send send :req req :sess sess)
  (is (= 55 (get-value env 'result4)))
  # Test 3: Multiple parameters shadowing multiple globals
  (e/run "(def a 1)" :env env :send send :req req :sess sess)
  (e/run "(def b 2)" :env env :send send :req req :sess sess)
  (e/run "(defn h [a b] (+ a b))" :env env :send send :req req :sess sess)
  (e/run "(def result5 (h 10 20))" :env env :send send :req req :sess sess)
  (is (= 30 (get-value env 'result5)))
  # Redefine globals - h should NOT be re-evaluated
  (e/run "(def a 100)" :env env :send send :req req :sess sess)
  (e/run "(def b 200)" :env env :send send :req req :sess sess)
  (e/run "(def result6 (h 10 20))" :env env :send send :req req :sess sess)
  (is (= 30 (get-value env 'result6)))
  # Test 4: Destructuring parameters
  (e/run "(def data [1 2 3])" :env env :send send :req req :sess sess)
  (e/run "(defn destructure [[x y]] (+ x y))" :env env :send send :req req :sess sess)
  (e/run "(def result7 (destructure [5 10]))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result7)))
  # Redefine x and data - destructure should NOT be re-evaluated (x is shadowed)
  (e/run "(def x 999)" :env env :send send :req req :sess sess)
  (e/run "(def data [100 200 300])" :env env :send send :req req :sess sess)
  (e/run "(def result8 (destructure [5 10]))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result8)))
  # Test 5: Anonymous function with shadowing
  (e/run "(def anon-f (fn [x] x))" :env env :send send :req req :sess sess)
  (e/run "(def result9 (anon-f 42))" :env env :send send :req req :sess sess)
  (is (= 42 (get-value env 'result9)))
  # Redefine x - anon-f should NOT be re-evaluated
  (e/run "(def x 123)" :env env :send send :req req :sess sess)
  (e/run "(def result10 (anon-f 42))" :env env :send send :req req :sess sess)
  (is (= 42 (get-value env 'result10)))
  # Test 6: Named function (fn with name)
  (e/run "(def named-f (fn my-func [x] x))" :env env :send send :req req :sess sess)
  (e/run "(def result11 (named-f 99))" :env env :send send :req req :sess sess)
  (is (= 99 (get-value env 'result11)))
  # Test 7: Function with parameter and body that references a different global
  (e/run "(def c 1000)" :env env :send send :req req :sess sess)
  (e/run "(defn mixed [x] (+ x c))" :env env :send send :req req :sess sess)
  (e/run "(def result12 (mixed 5))" :env env :send send :req req :sess sess)
  (is (= 1005 (get-value env 'result12)))
  # Redefine x (shadowed) - mixed should NOT be re-evaluated
  (e/run "(def x 777)" :env env :send send :req req :sess sess)
  (e/run "(def result13 (mixed 5))" :env env :send send :req req :sess sess)
  (is (= 1005 (get-value env 'result13)))
  # Redefine c (used in body) - mixed should be re-evaluated
  (e/run "(def c 2000)" :env env :send send :req req :sess sess)
  (e/run "(def result14 (mixed 5))" :env env :send send :req req :sess sess)
  (is (= 2005 (get-value env 'result14))))

(deftest deps-no-dependents
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define x with no dependents
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'x)))
  # Redefine x - should work fine, no re-evaluations needed
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'x)))
  # Output should contain the return value but no re-evaluation notes
  (def p (parser/new))
  (parser/consume p outb)
  (def messages @[])
  (while (parser/has-more p)
    (array/push messages (parser/produce p)))
  (is (= 1 (length messages)))
  (is (= "ret" (get-in messages [0 "tag"])))
  (is (= "20" (get-in messages [0 "val"]))))

(deftest deps-quoted-forms
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test 1: Quoted symbol - should NOT depend on the symbol's value
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y 'x)" :env env :send send :req req :sess sess)
  (is (= 'x (get-value env 'y)))
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (is (= 'x (get-value env 'y)))
  # Test 2: Quoted list - should NOT depend on symbols in the list
  (e/run "(def z '(+ x 5))" :env env :send send :req req :sess sess)
  (is (= '(+ x 5) (get-value env 'z)))
  (e/run "(def x 30)" :env env :send send :req req :sess sess)
  (is (= '(+ x 5) (get-value env 'z)))
  # Test 3: Quoted tuple vs array
  (e/run "(def a 1)" :env env :send send :req req :sess sess)
  (e/run "(def b 2)" :env env :send send :req req :sess sess)
  (e/run "(def tuple-quote '(a b))" :env env :send send :req req :sess sess)
  (e/run "(def array-quote '[a b])" :env env :send send :req req :sess sess)
  (is (= '(a b) (get-value env 'tuple-quote)))
  (is (= '[a b] (get-value env 'array-quote)))
  # Redefine - neither should update
  (e/run "(def a 100)" :env env :send send :req req :sess sess)
  (is (= '(a b) (get-value env 'tuple-quote)))
  (is (= '[a b] (get-value env 'array-quote)))
  # Test 4: Quasiquote without unquote - should NOT depend
  (e/run "(def quasi1 ~(+ x 5))" :env env :send send :req req :sess sess)
  (is (= ~(+ x 5) (get-value env 'quasi1)))
  (e/run "(def x 40)" :env env :send send :req req :sess sess)
  (is (= ~(+ x 5) (get-value env 'quasi1)))
  # Test 5: Quasiquote with unquote - SHOULD depend on unquoted symbols
  (e/run "(def quasi2 ~(+ ,x 5))" :env env :send send :req req :sess sess)
  (is (= ~(+ ,40 5) (get-value env 'quasi2)))
  (e/run "(def x 50)" :env env :send send :req req :sess sess)
  (is (= ~(+ ,50 5) (get-value env 'quasi2)))
  # Test 6: Nested quoted forms
  (e/run "(def c 7)" :env env :send send :req req :sess sess)
  (e/run "(def nested '(+ a '(* b c)))" :env env :send send :req req :sess sess)
  (is (= '(+ a '(* b c)) (get-value env 'nested)))
  (e/run "(def c 700)" :env env :send send :req req :sess sess)
  (is (= '(+ a '(* b c)) (get-value env 'nested)))
  # Test 7: Mix of quoted and unquoted in a data structure
  (e/run "(def d 8)" :env env :send send :req req :sess sess)
  (e/run "(def mixed [d 'x])" :env env :send send :req req :sess sess)
  (is (= [8 'x] (get-value env 'mixed)))
  # d changes, mixed should update (unquoted d)
  (e/run "(def d 9)" :env env :send send :req req :sess sess)
  (is (= [9 'x] (get-value env 'mixed)))
  # x changes, mixed should NOT update (quoted x)
  (e/run "(def x 999)" :env env :send send :req req :sess sess)
  (is (= [9 'x] (get-value env 'mixed))))

(deftest deps-variadic-functions
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test 1: & (rest parameter) with global reference
  (e/run "(def multiplier 10)" :env env :send send :req req :sess sess)
  (e/run "(defn f [a & rest] (+ a (* multiplier (length rest))))" :env env :send send :req req :sess sess)
  (e/run "(def result1 (f 5 1 2 3))" :env env :send send :req req :sess sess)
  (is (= 35 (get-value env 'result1)))  # 5 + (10 * 3) = 35
  # Redefine multiplier - f should be re-evaluated
  (e/run "(def multiplier 100)" :env env :send send :req req :sess sess)
  (e/run "(def result2 (f 5 1 2 3))" :env env :send send :req req :sess sess)
  (is (= 305 (get-value env 'result2)))  # 5 + (100 * 3) = 305
  # Test 2: &opt (optional parameter) with global reference
  (e/run "(defn g [a &opt b] (+ a (or b multiplier)))" :env env :send send :req req :sess sess)
  (e/run "(def result3 (g 10))" :env env :send send :req req :sess sess)
  (is (= 110 (get-value env 'result3)))  # 10 + 100 = 110
  (e/run "(def result4 (g 10 5))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result4)))  # 10 + 5 = 15
  # Test 3: Multiple &opt parameters
  (e/run "(def default1 20)" :env env :send send :req req :sess sess)
  (e/run "(def default2 30)" :env env :send send :req req :sess sess)
  (e/run "(defn h [a &opt b c] (+ a (or b default1) (or c default2)))" :env env :send send :req req :sess sess)
  (e/run "(def result5 (h 1))" :env env :send send :req req :sess sess)
  (is (= 51 (get-value env 'result5)))  # 1 + 20 + 30 = 51
  (e/run "(def result6 (h 1 2))" :env env :send send :req req :sess sess)
  (is (= 33 (get-value env 'result6)))  # 1 + 2 + 30 = 33
  (e/run "(def result7 (h 1 2 3))" :env env :send send :req req :sess sess)
  (is (= 6 (get-value env 'result7)))  # 1 + 2 + 3 = 6
  # Redefine defaults - h should be re-evaluated
  (e/run "(def default1 200)" :env env :send send :req req :sess sess)
  (e/run "(def default2 300)" :env env :send send :req req :sess sess)
  (e/run "(def result8 (h 1))" :env env :send send :req req :sess sess)
  (is (= 501 (get-value env 'result8)))  # 1 + 200 + 300 = 501
  # Test 4: Variadic parameter shadowing a global
  (e/run "(def rest 999)" :env env :send send :req req :sess sess)
  (e/run "(defn shadow-test [a & rest] (length rest))" :env env :send send :req req :sess sess)
  (e/run "(def result9 (shadow-test 1 2 3 4))" :env env :send send :req req :sess sess)
  (is (= 3 (get-value env 'result9)))  # rest parameter has 3 items
  # Redefine global rest - shadow-test should NOT be re-evaluated
  (e/run "(def rest 111)" :env env :send send :req req :sess sess)
  (e/run "(def result10 (shadow-test 1 2 3 4))" :env env :send send :req req :sess sess)
  (is (= 3 (get-value env 'result10)))  # Still 3, not affected by global
  # Test 5: &keys parameter
  (e/run "(def key-default 42)" :env env :send send :req req :sess sess)
  (e/run "(defn with-keys [a &keys {:x x :y y}] (+ a (or x key-default) (or y key-default)))" :env env :send send :req req :sess sess)
  (e/run "(def result11 (with-keys 1 :x 10 :y 20))" :env env :send send :req req :sess sess)
  (is (= 31 (get-value env 'result11)))  # 1 + 10 + 20 = 31
  (e/run "(def result12 (with-keys 1))" :env env :send send :req req :sess sess)
  (is (= 85 (get-value env 'result12)))  # 1 + 42 + 42 = 85
  # Redefine key-default - with-keys should be re-evaluated
  (e/run "(def key-default 100)" :env env :send send :req req :sess sess)
  (e/run "(def result13 (with-keys 1))" :env env :send send :req req :sess sess)
  (is (= 201 (get-value env 'result13)))  # 1 + 100 + 100 = 201
  # Test 6: &named parameter
  (e/run "(def named-default 7)" :env env :send send :req req :sess sess)
  (e/run "(defn with-named [a &named x y] (+ a (or x named-default) (or y named-default)))" :env env :send send :req req :sess sess)
  (e/run "(def result14 (with-named 1 :x 2 :y 3))" :env env :send send :req req :sess sess)
  (is (= 6 (get-value env 'result14)))  # 1 + 2 + 3 = 6
  (e/run "(def result15 (with-named 1))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result15)))  # 1 + 7 + 7 = 15
  # Redefine named-default - with-named should be re-evaluated
  (e/run "(def named-default 50)" :env env :send send :req req :sess sess)
  (e/run "(def result16 (with-named 1))" :env env :send send :req req :sess sess)
  (is (= 101 (get-value env 'result16))))  # 1 + 50 + 50 = 101

(deftest deps-nested-functions
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define global x
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  # Define function that returns closure capturing x
  (e/run "(defn outer [] (fn [] x))" :env env :send send :req req :sess sess)
  (e/run "(def inner (outer))" :env env :send send :req req :sess sess)
  (e/run "(def result1 (inner))" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'result1)))
  # Redefine x - outer should be re-evaluated, which re-evaluates inner
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (e/run "(def inner2 (outer))" :env env :send send :req req :sess sess)
  (e/run "(def result2 (inner2))" :env env :send send :req req :sess sess)
  (is (= 20 (get-value env 'result2))))

(deftest deps-destructuring
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test array destructuring
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y 20)" :env env :send send :req req :sess sess)
  (e/run "(def [a b] [x y])" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'a)))
  (is (= 20 (get-value env 'b)))
  # Redefine x, destructured bindings should update
  (buffer/clear outb)
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  (is (= 100 (get-value env 'a)))
  (is (= 20 (get-value env 'b)))
  # Test struct destructuring
  (e/run "(def data {:foo 1 :bar 2})" :env env :send send :req req :sess sess)
  (e/run "(def {:foo f :bar b} data)" :env env :send send :req req :sess sess)
  (is (= 1 (get-value env 'f)))
  (is (= 2 (get-value env 'b)))
  # Redefine data, destructured bindings should update
  (buffer/clear outb)
  (e/run "(def data {:foo 10 :bar 20})" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'f)))
  (is (= 20 (get-value env 'b))))

(deftest deps-loop-bindings
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test that loop bindings are scoped correctly (i should not be tracked as dependency)
  (e/run "(def n 5)" :env env :send send :req req :sess sess)
  (e/run "(def total1 (do (var acc 0) (loop [i :range [0 n]] (+= acc i)) acc))" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'total1)))  # 0+1+2+3+4 = 10
  # Redefine n, total1 should be re-evaluated with new range
  (buffer/clear outb)
  (e/run "(def n 4)" :env env :send send :req req :sess sess)
  (is (= 6 (get-value env 'total1)))
  # Test loop with :in modifier and external reference
  (e/run "(def items [1 2 3])" :env env :send send :req req :sess sess)
  (e/run "(def multiplier 10)" :env env :send send :req req :sess sess)
  (e/run "(def total2 (do (var acc 0) (loop [item :in items] (+= acc (* item multiplier))) acc))" :env env :send send :req req :sess sess)
  (is (= 60 (get-value env 'total2)))  # (1+2+3) * 10 = 60
  # Redefine multiplier - total2 should be re-evaluated
  (buffer/clear outb)
  (e/run "(def multiplier 5)" :env env :send send :req req :sess sess)
  (is (= 30 (get-value env 'total2))))  # (1+2+3) * 5 = 30

(deftest deps-chained-dependencies
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create chain a -> b -> c
  (e/run "(def a 1)" :env env :send send :req req :sess sess)
  (e/run "(def b (+ a 1))" :env env :send send :req req :sess sess)
  (e/run "(def c (+ b 1))" :env env :send send :req req :sess sess)
  (is (= 1 (get-value env 'a)))
  (is (= 2 (get-value env 'b)))
  (is (= 3 (get-value env 'c)))
  # Redefine a, both b and c should update
  (e/run "(def a 10)" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'a)))
  (is (= 11 (get-value env 'b)))
  (is (= 12 (get-value env 'c))))

(deftest deps-function-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define variable and function that uses it
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(defn f [] (+ x 5))" :env env :send send :req req :sess sess)
  (e/run "(def result1 (f))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'result1)))
  # Redefine x, function should be recompiled
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (e/run "(def result2 (f))" :env env :send send :req req :sess sess)
  (is (= 25 (get-value env 'result2))))

(deftest deps-transitive-through-function
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define a -> g (function) -> b (calls g)
  (e/run "(def a 5)" :env env :send send :req req :sess sess)
  (e/run "(defn g [] (+ a 10))" :env env :send send :req req :sess sess)
  (e/run "(def b (g))" :env env :send send :req req :sess sess)
  (is (= 15 (get-value env 'b)))
  # Redefine a, both g and b should update
  (e/run "(def a 100)" :env env :send send :req req :sess sess)
  (is (= 110 (get-value env 'b))))

(deftest deps-multiple-dependencies
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # z depends on both x and y
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y 20)" :env env :send send :req req :sess sess)
  (e/run "(def z (+ x y))" :env env :send send :req req :sess sess)
  (is (= 30 (get-value env 'z)))
  # Redefine x, z should update
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  (is (= 120 (get-value env 'z)))
  # Redefine y, z should update again
  (e/run "(def y 5)" :env env :send send :req req :sess sess)
  (is (= 105 (get-value env 'z))))

(deftest deps-multiple-dependents
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Both c and d depend on a and b
  (e/run "(def a 1)" :env env :send send :req req :sess sess)
  (e/run "(def b 2)" :env env :send send :req req :sess sess)
  (e/run "(def c (+ a b))" :env env :send send :req req :sess sess)
  (e/run "(def d (* a b))" :env env :send send :req req :sess sess)
  (is (= 3 (get-value env 'c)))
  (is (= 2 (get-value env 'd)))
  # Redefine a, both c and d should update
  (e/run "(def a 10)" :env env :send send :req req :sess sess)
  (is (= 12 (get-value env 'c)))
  (is (= 20 (get-value env 'd))))

(deftest deps-diamond-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create diamond: a depends on b and c, both b and c depend on d
  (e/run "(def d 5)" :env env :send send :req req :sess sess)
  (e/run "(def b (+ d 10))" :env env :send send :req req :sess sess)
  (e/run "(def c (+ d 20))" :env env :send send :req req :sess sess)
  (e/run "(def a (+ b c))" :env env :send send :req req :sess sess)
  (is (= 5 (get-value env 'd)))
  (is (= 15 (get-value env 'b)))
  (is (= 25 (get-value env 'c)))
  (is (= 40 (get-value env 'a)))
  # Redefine d - b and c should update, then a should update once with both new values
  (e/run "(def d 100)" :env env :send send :req req :sess sess)
  (is (= 100 (get-value env 'd)))
  (is (= 110 (get-value env 'b)))
  (is (= 120 (get-value env 'c)))
  (is (= 230 (get-value env 'a))))

(deftest deps-circular-direct
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create circular dependency a <-> b
  (e/run "(def a 10)" :env env :send send :req req :sess sess)
  (e/run "(def b a)" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'b)))
  # Close the loop
  (e/run "(def a b)" :env env :send send :req req :sess sess)
  (is (= 10 (get-value env 'a)))
  # Redefine b, should not infinite loop
  (e/run "(def b 100)" :env env :send send :req req :sess sess)
  (is (= 100 (get-value env 'b)))
  (is (= 100 (get-value env 'a))))

(deftest deps-circular-indirect
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create cycle x -> y -> z -> x
  (e/run "(def x 1)" :env env :send send :req req :sess sess)
  (e/run "(def y 2)" :env env :send send :req req :sess sess)
  (e/run "(def z 3)" :env env :send send :req req :sess sess)
  (e/run "(def x y)" :env env :send send :req req :sess sess)
  (e/run "(def y z)" :env env :send send :req req :sess sess)
  (e/run "(def z x)" :env env :send send :req req :sess sess)
  # Redefine any, should not infinite loop
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  (is (= 100 (get-value env 'x)))
  (is (= 100 (get-value env 'y)))
  (is (= 100 (get-value env 'z))))

(deftest deps-error-handling
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def path (dyn :current-file))
  (def sess @{:dep-graph @{}})
  # Define x as a function, y calls it, z uses it
  (e/run "(def x +)" :env env :send send :req req :sess sess)
  (e/run "(def y (x 1 2))" :env env :send send :req req :sess sess)
  (e/run "(def z (+ x 100))" :env env :send send :req req :sess sess)
  (is (= 3 (get-value env 'y)))
  # Redefine x to a symbol (will cause errors in re-evaluation)
  (buffer/clear outb)
  (e/run "(def x 'not-a-function)" :env env :send send :req req :sess sess)
  # y should keep old value (re-eval failed)
  (is (= 3 (get-value env 'y)))
  # Check exact error messages
  (parser/consume p outb)
  (def messages @[])
  (while (parser/has-more p)
    (array/push messages (parser/produce p)))
  # Should have exactly 4 messages
  (is (= 4 (length messages)))
  # First message should be the successful redefinition of x
  (def expect-1
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "not-a-function"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false})
  (is (== expect-1 (get messages 0)))
  # Second message should be note about re-evaluation
  (def expect-2
    {"tag" "note"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "val" "Re-evaluating dependents of x: z, y"})
  (is (== expect-2 (get messages 1)))
  # Third message should be an error for z re-evaluation
  (def msg-3 (get messages 2))
  (is (= "err" (get msg-3 "tag")))
  (is (= "error: could not find method :+ for not-a-function" (get msg-3 "val")))
  # Fourth message should be an error for y re-evaluation
  (def msg-4 (get messages 3))
  (is (= "err" (get msg-4 "tag")))
  (is (= "compile error: not-a-function expects 1 argument, got 2" (get msg-4 "val"))))

(deftest deps-informational-messages
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define dependencies
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y (+ x 5))" :env env :send send :req req :sess sess)
  # Redefine x and check for note message
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def messages @[])
  (while (parser/has-more p)
    (array/push messages (parser/produce p)))
  # Should have exactly 3 messages
  (is (= 3 (length messages)))
  # First message should be the return value
  (def expect-1
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "20"
     "janet/path" u/ns
     "janet/line" 1
     "janet/col" 1
     "janet/reeval?" false})
  (is (== expect-1 (get messages 0)))
  # Second message should be the informational note about re-evaluation
  (def expect-2
    {"tag" "note"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "val" "Re-evaluating dependents of x: y"})
  (is (== expect-2 (get messages 1)))
  # Third message should be the return value from re-evaluating y
  # This is a cascaded reevaluation, so grapple/secondary? is true
  (def expect-3
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "25"
     "janet/path" u/ns
     "janet/reeval?" true})
  (is (== expect-3 (get messages 2))))

# Cross-environment binding dependency tests (individual form evaluation)

(deftest deps-cross-env-binding-simple
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create base environment and evaluate a binding
  (def base-path "/test-base-env.janet")
  (def base-env (e/eval-make-env))
  (put module/cache base-path base-env)
  (e/run "(def value 10)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Create using environment that imports base
  (def using-path "/test-using-env.janet")
  (def using-env (e/eval-make-env))
  (put module/cache using-path using-env)
  (e/run (string "(import " base-path " :as base)")
         :env using-env :send send :req req :path using-path :sess sess)
  (e/run "(def result (+ base/value 20))"
         :env using-env :send send :req req :path using-path :sess sess)
  # Check initial values
  (is (= 10 (get-value base-env 'value)))
  (is (= 30 (get-value using-env 'result)))  # 10 + 20
  # Redefine value in base environment
  (buffer/clear outb)
  (e/run "(def value 100)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Check if result updated in using environment (may not work yet)
  (is (= 100 (get-value base-env 'value)))
  (is (= 120 (get-value using-env 'result))))  # Expected: 100 + 20

(deftest deps-cross-env-binding-multiple
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create base environment
  (def base-path "/test-shared-env.janet")
  (def base-env (e/eval-make-env))
  (put module/cache base-path base-env)
  (e/run "(def shared 10)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Create first importing environment
  (def env1-path "/test-env1.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (e/run (string "(import " base-path " :as base)")
         :env env1 :send send :req req :path env1-path :sess sess)
  (e/run "(def local1 (+ base/shared 1))"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Create second importing environment
  (def env2-path "/test-env2.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (e/run (string "(import " base-path " :as base)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (e/run "(def local2 (* base/shared 2))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Check initial values
  (is (= 10 (get-value base-env 'shared)))
  (is (= 11 (get-value env1 'local1)))  # 10 + 1
  (is (= 20 (get-value env2 'local2)))  # 10 * 2
  # Redefine shared in base environment
  (buffer/clear outb)
  (e/run "(def shared 50)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Check if both importers updated (may not work yet)
  (is (= 50 (get-value base-env 'shared)))
  (is (= 51 (get-value env1 'local1)))  # Expected: 50 + 1
  (is (= 100 (get-value env2 'local2))))  # Expected: 50 * 2

(deftest deps-cross-env-binding-transitive
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create level1 environment
  (def level1-path "/test-l1-env.janet")
  (def level1-env (e/eval-make-env))
  (put module/cache level1-path level1-env)
  (e/run "(def root 100)"
         :env level1-env :send send :req req :path level1-path :sess sess)
  # Create level2 environment that imports level1
  (def level2-path "/test-l2-env.janet")
  (def level2-env (e/eval-make-env))
  (put module/cache level2-path level2-env)
  (e/run (string "(import " level1-path " :as l1)")
         :env level2-env :send send :req req :path level2-path :sess sess)
  (e/run "(def middle (+ l1/root 50))"
         :env level2-env :send send :req req :path level2-path :sess sess)
  # Create level3 environment that imports level2
  (def level3-path "/test-l3-env.janet")
  (def level3-env (e/eval-make-env))
  (put module/cache level3-path level3-env)
  (e/run (string "(import " level2-path " :as l2)")
         :env level3-env :send send :req req :path level3-path :sess sess)
  (e/run "(def top (* l2/middle 2))"
         :env level3-env :send send :req req :path level3-path :sess sess)
  # Check initial values
  (is (= 100 (get-value level1-env 'root)))
  (is (= 150 (get-value level2-env 'middle)))  # 100 + 50
  (is (= 300 (get-value level3-env 'top)))  # 150 * 2
  # Redefine root in level1
  (buffer/clear outb)
  (e/run "(def root 200)"
         :env level1-env :send send :req req :path level1-path :sess sess)
  # Check if all levels updated transitively (may not work yet)
  (is (= 200 (get-value level1-env 'root)))
  (is (= 250 (get-value level2-env 'middle)))  # Expected: 200 + 50
  (is (= 500 (get-value level3-env 'top))))  # Expected: 250 * 2

(deftest deps-cross-env-binding-circular
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create env1 with binding 'x'
  (def env1-path "/test-circ1.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (e/run "(def x 10)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Create env2 that imports env1 and defines 'y'
  (def env2-path "/test-circ2.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (e/run (string "(import " env1-path " :as e1)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (e/run "(def y (+ e1/x 5))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Create circular reference: env1 imports env2 and uses 'y'
  (e/run (string "(import " env2-path " :as e2)")
         :env env1 :send send :req req :path env1-path :sess sess)
  (e/run "(def z (* e2/y 2))"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Check initial values
  (is (= 10 (get-value env1 'x)))
  (is (= 15 (get-value env2 'y)))  # 10 + 5
  (is (= 30 (get-value env1 'z)))  # 15 * 2
  # Redefine x - should update y, then z, without infinite loop
  (buffer/clear outb)
  (e/run "(def x 20)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Verify cascade worked and didn't infinite loop
  (is (= 20 (get-value env1 'x)))
  (is (= 25 (get-value env2 'y)))  # 20 + 5
  (is (= 50 (get-value env1 'z))))  # 25 * 2

(deftest deps-cross-env-binding-diamond
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create top of diamond: env1 with 'root'
  (def env1-path "/test-diamond-top.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (e/run "(def root 100)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Left side: env2 imports env1, defines 'left'
  (def env2-path "/test-diamond-left.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (e/run (string "(import " env1-path " :as top)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (e/run "(def left (+ top/root 10))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Right side: env3 imports env1, defines 'right'
  (def env3-path "/test-diamond-right.janet")
  (def env3 (e/eval-make-env))
  (put module/cache env3-path env3)
  (e/run (string "(import " env1-path " :as top)")
         :env env3 :send send :req req :path env3-path :sess sess)
  (e/run "(def right (+ top/root 20))"
         :env env3 :send send :req req :path env3-path :sess sess)
  # Bottom of diamond: env4 imports both env2 and env3
  (def env4-path "/test-diamond-bottom.janet")
  (def env4 (e/eval-make-env))
  (put module/cache env4-path env4)
  (e/run (string "(import " env2-path " :as left-side)")
         :env env4 :send send :req req :path env4-path :sess sess)
  (e/run (string "(import " env3-path " :as right-side)")
         :env env4 :send send :req req :path env4-path :sess sess)
  (e/run "(def bottom (+ left-side/left right-side/right))"
         :env env4 :send send :req req :path env4-path :sess sess)
  # Check initial values
  (is (= 100 (get-value env1 'root)))
  (is (= 110 (get-value env2 'left)))   # 100 + 10
  (is (= 120 (get-value env3 'right)))  # 100 + 20
  (is (= 230 (get-value env4 'bottom))) # 110 + 120
  # Redefine root - should propagate through diamond correctly
  (buffer/clear outb)
  (e/run "(def root 200)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Verify all paths updated correctly
  (is (= 200 (get-value env1 'root)))
  (is (= 210 (get-value env2 'left)))   # 200 + 10
  (is (= 220 (get-value env3 'right)))  # 200 + 20
  (is (= 430 (get-value env4 'bottom))))  # 210 + 220 (should update once, not twice)

(deftest deps-cross-env-binding-error-cascade
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create env1 with a binding that will be changed to cause errors
  (def env1-path "/test-error1.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (e/run "(def fn-or-val +)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Create env2 that calls fn-or-val (works when it's a function)
  (def env2-path "/test-error2.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (e/run (string "(import " env1-path " :as e1)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (e/run "(def result (e1/fn-or-val 5 10))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Create env3 that depends on env2's result
  (def env3-path "/test-error3.janet")
  (def env3 (e/eval-make-env))
  (put module/cache env3-path env3)
  (e/run (string "(import " env2-path " :as e2)")
         :env env3 :send send :req req :path env3-path :sess sess)
  (e/run "(def final (* e2/result 2))"
         :env env3 :send send :req req :path env3-path :sess sess)
  # Check initial values
  (is (= 15 (get-value env2 'result)))  # (+ 5 10)
  (is (= 30 (get-value env3 'final)))   # (* 15 2)
  # Redefine fn-or-val to a string (will cause error when called)
  (buffer/clear outb)
  (e/run "(def fn-or-val \"not-a-function\")"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Verify env1 updated, but env2 and env3 kept old values due to error
  (is (= "not-a-function" (get-value env1 'fn-or-val)))
  (is (= 15 (get-value env2 'result)))  # Should keep old value after error
  (is (= 30 (get-value env3 'final))))  # Should keep old value (cascade stopped)

# Cross-file dependency tests (whole-file reloads)

(deftest deps-cross-file-simple
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def send-note (fn [msg &opt details] nil))
  (def sess @{:dep-graph @{}})
  # Use permanent test module files
  (def base-path (string (os/cwd) "/res/test/base.janet"))
  (def using-path (string (os/cwd) "/res/test/using.janet"))
  # Load base module
  (def base-env (e/eval-make-env))
  (put module/cache base-path base-env)
  (e/run (slurp base-path)
         :env base-env :send send :req req :path base-path :sess sess)
  # Load using module
  (def using-env (e/eval-make-env))
  (put module/cache using-path using-env)
  (e/run (slurp using-path)
         :env using-env :send send :req req :path using-path :sess sess)
  # Check initial values
  (is (= 10 (get-value base-env 'value)))
  (is (= 5 (get-value base-env 'multiplier)))
  (is (= 30 (get-value using-env 'result)))  # 10 + 20
  (is (= 15 (get-value using-env 'calculated)))  # 5 * 3
  # Modify and reload base module
  (spit base-path "(def value 100)\n(def multiplier 10)\n")
  (buffer/clear outb)
  (e/run (slurp base-path)
         :env base-env :send send :req req :path base-path :sess sess)
  # Trigger cross-file reevaluation
  (e/cross-reeval base-path sess send-note)
  # Check that values updated in both modules
  (is (= 100 (get-value base-env 'value)))
  (is (= 10 (get-value base-env 'multiplier)))
  (is (= 120 (get-value using-env 'result)))  # 100 + 20
  (is (= 30 (get-value using-env 'calculated)))  # 10 * 3
  # Restore original file content
  (spit base-path "(def value 10)\n(def multiplier 5)\n"))

(deftest deps-cross-file-multiple-importers
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def send-note (fn [msg &opt details] nil))
  (def sess @{:dep-graph @{}})
  # Use permanent test module files
  (def base-path (string (os/cwd) "/res/test/shared.janet"))
  (def user1-path (string (os/cwd) "/res/test/user1.janet"))
  (def user2-path (string (os/cwd) "/res/test/user2.janet"))
  # Load all modules
  (def base-env (e/eval-make-env))
  (put module/cache base-path base-env)
  (e/run (slurp base-path)
         :env base-env :send send :req req :path base-path :sess sess)
  (def user1-env (e/eval-make-env))
  (put module/cache user1-path user1-env)
  (e/run (slurp user1-path)
         :env user1-env :send send :req req :path user1-path :sess sess)
  (def user2-env (e/eval-make-env))
  (put module/cache user2-path user2-env)
  (e/run (slurp user2-path)
         :env user2-env :send send :req req :path user2-path :sess sess)
  # Check initial values
  (is (= 10 (get-value base-env 'shared)))
  (is (= 11 (get-value user1-env 'local1)))  # 10 + 1
  (is (= 20 (get-value user2-env 'local2)))  # 10 * 2
  # Modify and reload base module
  (spit base-path "(def shared 50)\n")
  (buffer/clear outb)
  (e/run (slurp base-path)
         :env base-env :send send :req req :path base-path :sess sess)
  # Trigger cross-file reevaluation
  (e/cross-reeval base-path sess send-note)
  # Check that both importers updated
  (is (= 50 (get-value base-env 'shared)))
  (is (= 51 (get-value user1-env 'local1)))  # 50 + 1
  (is (= 100 (get-value user2-env 'local2)))  # 50 * 2
  # Restore original file content
  (spit base-path "(def shared 10)\n"))

(deftest deps-cross-file-transitive
  (table/clear module/cache)
  (def outb @"")
  (def send (make-sender outb))
  (def send-note (fn [msg &opt details] nil))
  (def sess @{:dep-graph @{}})
  # Use permanent test module files with transitive dependencies
  (def level1-path (string (os/cwd) "/res/test/level1.janet"))
  (def level2-path (string (os/cwd) "/res/test/level2.janet"))
  (def level3-path (string (os/cwd) "/res/test/level3.janet"))
  # Load all modules in order
  (def level1-env (e/eval-make-env))
  (put module/cache level1-path level1-env)
  (e/run (slurp level1-path)
         :env level1-env :send send :req req :path level1-path :sess sess)
  (def level2-env (e/eval-make-env))
  (put module/cache level2-path level2-env)
  (e/run (slurp level2-path)
         :env level2-env :send send :req req :path level2-path :sess sess)
  (def level3-env (e/eval-make-env))
  (put module/cache level3-path level3-env)
  (e/run (slurp level3-path)
         :env level3-env :send send :req req :path level3-path :sess sess)
  # Check initial values
  (is (= 100 (get-value level1-env 'root)))
  (is (= 150 (get-value level2-env 'middle)))  # 100 + 50
  (is (= 300 (get-value level3-env 'top)))  # 150 * 2
  # Modify and reload level1
  (spit level1-path "(def root 200)\n")
  (buffer/clear outb)
  (e/run (slurp level1-path)
         :env level1-env :send send :req req :path level1-path :sess sess)
  # Trigger cross-file reevaluation for level1
  (e/cross-reeval level1-path sess send-note)
  # Check that level2 updated
  (is (= 200 (get-value level1-env 'root)))
  (is (= 250 (get-value level2-env 'middle)))  # 200 + 50
  # Now trigger cross-file reevaluation for level2 to propagate to level3
  (e/cross-reeval level2-path sess send-note)
  # Check that level3 updated
  (is (= 500 (get-value level3-env 'top)))  # 250 * 2
  # Restore original file content
  (spit level1-path "(def root 100)\n"))

(run-tests!)

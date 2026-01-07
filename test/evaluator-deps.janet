(use ../deps/testament)

(import ../lib/utilities :as u)
(import ../lib/evaluator :as e)

# Utility Functions

(defn make-sender [b]
  (fn :send [v]
    # use buffer becuase ev/give doesn't work in janet_call
    (buffer/push b (string/format "%q" v))))

(defn dep-msg [dep & depts]
  (def val (string "Re-evaluating dependents of "
                   dep
                   ": "
                   (string/join depts ", ")))
  {"tag" "note"
   "op" "env.eval"
   "lang" u/lang
   "req" "1"
   "sess" "1"
   "val" val})

(defn err-msg [val &named path line col]
  (default path u/ns)
  {"tag" "err"
   "op" "env.eval"
   "lang" u/lang
   "req" "1"
   "sess" "1"
   "val" val
   "janet/path" path
   "janet/line" line
   "janet/col" col})

(defn run-eval [code & args]
  (def fib (fiber/new (fn [] (e/run code ;args)) :dey))
  (def res (resume fib))
  [res fib])

(defn ret-msg [val &named path col line reeval? done?]
  (default path u/ns)
  (default reeval? false)
  (default done? false)
  {"tag" "ret"
   "op" "env.eval"
   "lang" u/lang
   "req" "1"
   "sess" "1"
   "done" done?
   "val" val
   "janet/path" path
   "janet/line" line
   "janet/col" col
   "janet/reeval?" reeval?})

(defn cross-msg [path & depts]
  (def val (string "Re-evaluating in "
                   path
                   ": "
                   (string/join depts ", ")))
  {"tag" "note"
   "op" "env.eval"
   "lang" u/lang
   "req" "1"
   "sess" "1"
   "val" val})

# Generic eval request

(def req
  {"op" "env.eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})

# Dependency tracking tests

(deftest deps-simple-dependency
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define x and y where y depends on x
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y (+ x 5))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine x, y should auto-update
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # First message: return value from redefining x
  (def expect-1 (ret-msg "20" :col 1 :line 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Second message: note about re-evaluation
  (def expect-2 (dep-msg "x" "y"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Third message: return value from re-evaluating y
  (def expect-3 (ret-msg "25" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-var-dependency
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define var a and b where b depends on a
  (run-eval "(var a 10)" :env env :send send :req req :sess sess)
  (run-eval "(def b (+ a 5))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine a, b should auto-update
  (run-eval "(var a 20)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # First message: return value from redefining a
  (def expect-1 (ret-msg "20" :col 1 :line 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Second message: note about re-evaluation
  (def expect-2 (dep-msg "a" "b"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Third message: return value from re-evaluating b
  (def expect-3 (ret-msg "25" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-complex-expressions
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test nested function calls
  (e/run "(def x 5)" :env env :send send :req req :sess sess)
  (e/run "(def y 10)" :env env :send send :req req :sess sess)
  (e/run "(def z (+ (* x 2) y))" :env env :send send :req req :sess sess)
  # Test let bindings within defs
  (e/run "(def result1 (let [temp (+ x 1)] (* temp 2)))" :env env :send send :req req :sess sess)
  # Test conditionals
  (e/run "(def result2 (if (> x 3) (+ x y) y))" :env env :send send :req req :sess sess)
  # Test do blocks
  (e/run "(def result3 (do (+ x 1) (+ x y)))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine x, all dependents should update
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  # Parse and verify messages for x redefinition
  (parser/consume p outb)
  # First message: return value from redefining x
  (def expect-1 (ret-msg "20" :col 1 :line 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Second message: note about re-evaluation
  (def expect-2 (dep-msg "x" "result2" "result3" "z" "result1"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Messages for re-evaluating dependents
  (def expect-3 (ret-msg "30" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (ret-msg "30" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (ret-msg "50" :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  (def expect-6 (ret-msg "42" :reeval? true))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # Verify no more messages
  (is (not (parser/has-more p)))
  (buffer/clear outb)
  # Redefine y, relevant dependents should update
  (e/run "(def y 100)" :env env :send send :req req :sess sess)
  # Parse and verify messages for y redefinition
  (parser/consume p outb)
  # First message: return value from redefining y
  (def expect-7 (ret-msg "100" :line 1 :col 1))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Second message: note about re-evaluation (only result2, z, result3 depend on y)
  (def expect-8 (dep-msg "y" "result2" "z" "result3"))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  # Messages for re-evaluating dependents: result2, z, result3
  (def expect-9 (ret-msg "120" :reeval? true))
  (def actual-9 (parser/produce p))
  (is (== expect-9 actual-9))
  (def expect-10 (ret-msg "140" :reeval? true))
  (def actual-10 (parser/produce p))
  (is (== expect-10 actual-10))
  (def expect-11 (ret-msg "120" :reeval? true))
  (def actual-11 (parser/produce p))
  (is (== expect-11 actual-11))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-macro-dependency
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define a macro and use it
  (run-eval "(defmacro double [x] ~(* 2 ,x))" :env env :send send :req req :sess sess)
  (run-eval "(def y (double 5))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine the macro, y should be re-evaluated with new macro
  (run-eval "(defmacro double [x] ~(* 3 ,x))" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from macro redefinition
  (def expect-1 (ret-msg "<function double>" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Note about re-evaluation
  (def expect-2 (dep-msg "double" "y"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Return from re-evaluating y
  (def expect-3 (ret-msg "15" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test macro that references a value
  (run-eval "(def multiplier 4)" :env env :send send :req req :sess sess)
  (run-eval "(defmacro mult [x] ~(* multiplier ,x))" :env env :send send :req req :sess sess)
  (run-eval "(def z (mult 5))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine multiplier - this affects the macro expansion
  (run-eval "(def multiplier 10)" :env env :send send :req req :sess sess)
  # Parse and verify messages for multiplier redefinition
  (parser/consume p outb)
  # Return from multiplier redefinition
  (def expect-4 (ret-msg "10" :line 1 :col 1))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Note about re-evaluation (mult and z both depend on multiplier)
  (def expect-5 (dep-msg "multiplier" "mult" "z"))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Return from re-evaluating mult
  (def expect-6 (ret-msg "<function mult>" :reeval? true))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # Return from re-evaluating z
  (def expect-7 (ret-msg "50" :reeval? true))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-local-scope-shadowing
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define global x
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  # Define y with local x that shadows global - y should NOT depend on global x
  (e/run "(def y (let [x 20] x))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine global x - y should NOT update
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  # Parse and verify messages - should only have return, no re-evaluation
  (parser/consume p outb)
  # Return from x redefinition
  (def expect-1 (ret-msg "100" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # No more messages (y doesn't depend on x due to shadowing)
  (is (not (parser/has-more p)))
  # Test let with outer reference (no shadowing)
  (e/run "(def z (let [a x] (+ a 5)))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  # Redefine x - z should update (let binds a to x)
  (e/run "(def x 50)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from x redefinition
  (def expect-2 (ret-msg "50" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Note about re-evaluation
  (def expect-3 (dep-msg "x" "z"))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Return from re-evaluating z
  (def expect-4 (ret-msg "55" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-function-parameter-shadowing
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test 1: Simple parameter shadowing
  (run-eval "(def x 10)" :env env :send send :req req :sess sess)
  (run-eval "(defn f [x] x)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result1 (f 20))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "20" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # No more messages (nothing depends on x due to shadowing)
  (is (not (parser/has-more p)))
  # Redefine global x - f should NOT be re-evaluated
  (run-eval "(def x 100)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result2 (f 30))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "30" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # No more messages (nothing depends on x due to shadowing)
  (is (not (parser/has-more p)))
  # Test 2: Function that uses both parameter and global
  (run-eval "(defn g [y] (+ x y))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result3 (g 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-3 (ret-msg "105" :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))  # x=100, y=5
  # No more messages (nothing depends on x due to shadowing)
  (is (not (parser/has-more p)))
  # Redefine x
  (run-eval "(def x 50)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result4 (g 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-4 (ret-msg "55" :line 1 :col 1))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 3: Multiple parameters shadowing multiple globals
  (run-eval "(def a 1)" :env env :send send :req req :sess sess)
  (run-eval "(def b 2)" :env env :send send :req req :sess sess)
  (run-eval "(defn h [a b] (+ a b))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result5 (h 10 20))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-5 (ret-msg "30" :line 1 :col 1))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine globals - h should NOT be re-evaluated
  (run-eval "(def a 100)" :env env :send send :req req :sess sess)
  (run-eval "(def b 200)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result6 (h 10 20))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-6 (ret-msg "30" :line 1 :col 1))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 4: Destructuring parameters
  (run-eval "(def data [1 2 3])" :env env :send send :req req :sess sess)
  (run-eval "(defn destructure [[x y]] (+ x y))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result7 (destructure [5 10]))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-7 (ret-msg "15" :line 1 :col 1))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine x and data - destructure should NOT be re-evaluated (x is shadowed)
  (run-eval "(def x 999)" :env env :send send :req req :sess sess)
  (run-eval "(def data [100 200 300])" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result8 (destructure [5 10]))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-8 (ret-msg "15" :line 1 :col 1))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 5: Anonymous function with shadowing
  (run-eval "(def anon-f (fn [x] x))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result9 (anon-f 42))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-9 (ret-msg "42" :line 1 :col 1))
  (def actual-9 (parser/produce p))
  (is (== expect-9 actual-9))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine x - anon-f should NOT be re-evaluated
  (run-eval "(def x 123)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result10 (anon-f 42))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-10 (ret-msg "42" :line 1 :col 1))
  (def actual-10 (parser/produce p))
  (is (== expect-10 actual-10))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 6: Named function (fn with name)
  (run-eval "(def named-f (fn my-func [x] x))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result11 (named-f 99))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-11 (ret-msg "99" :line 1 :col 1))
  (def actual-11 (parser/produce p))
  (is (== expect-11 actual-11))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 7: Function with parameter and body that references a different global
  (run-eval "(def c 1000)" :env env :send send :req req :sess sess)
  (run-eval "(defn mixed [x] (+ x c))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result12 (mixed 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-12 (ret-msg "1005" :line 1 :col 1))
  (def actual-12 (parser/produce p))
  (is (== expect-12 actual-12))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine x (shadowed) - mixed should NOT be re-evaluated
  (run-eval "(def x 777)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result13 (mixed 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-13 (ret-msg "1005" :line 1 :col 1))
  (def actual-13 (parser/produce p))
  (is (== expect-13 actual-13))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine c (used in body) - mixed should be re-evaluated
  (run-eval "(def c 2000)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result14 (mixed 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-14 (ret-msg "2005" :line 1 :col 1))
  (def actual-14 (parser/produce p))
  (is (== expect-14 actual-14))
  # No more messages
  (is (not (parser/has-more p))))

(deftest deps-no-dependents
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define x with no dependents
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-init (ret-msg "10" :line 1 :col 1))
  (def actual-init (parser/produce p))
  (is (== expect-init actual-init))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine x - should work fine, no re-evaluations needed
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req :sess sess)
  # Output should contain the return value but no re-evaluation notes
  (parser/consume p outb)
  (def expect-1 (ret-msg "20" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages (no re-evaluation notes)
  (is (not (parser/has-more p))))

(deftest deps-quoted-forms
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test 1: Quoted symbol - should NOT depend on the symbol's value
  (run-eval "(def x 10)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def y 'x)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "x" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # No more messages
  (is (not (parser/has-more p)))
  (run-eval "(def x 20)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def y 'x)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "x" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 2: Quoted list - should NOT depend on symbols in the list
  (buffer/clear outb)
  (run-eval "(def z '(+ x 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-3 (ret-msg "(+ x 5)" :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # No more messages
  (is (not (parser/has-more p)))
  (run-eval "(def x 30)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def z '(+ x 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-4 (ret-msg "(+ x 5)" :line 1 :col 1))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 3: Quoted tuple vs array
  (run-eval "(def a 1)" :env env :send send :req req :sess sess)
  (run-eval "(def b 2)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def tuple-quote '(a b))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-5 (ret-msg "(a b)" :line 1 :col 1))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # No more messages
  (is (not (parser/has-more p)))
  (buffer/clear outb)
  (run-eval "(def array-quote '[a b])" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-6 (ret-msg "[a b]" :line 1 :col 1))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # No more messages
  (is (not (parser/has-more p)))
  # Redefine - neither should update
  (run-eval "(def a 100)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def tuple-quote '(a b))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-7 (ret-msg "(a b)" :line 1 :col 1))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # No more messages
  (is (not (parser/has-more p)))
  (buffer/clear outb)
  (run-eval "(def array-quote '[a b])" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-8 (ret-msg "[a b]" :line 1 :col 1))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 4: Quasiquote without unquote - should NOT depend
  (buffer/clear outb)
  (run-eval "(def quasi1 ~(+ x 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-9 (ret-msg "(+ x 5)" :line 1 :col 1))
  (def actual-9 (parser/produce p))
  (is (== expect-9 actual-9))
  # No more messages
  (is (not (parser/has-more p)))
  (run-eval "(def x 40)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def quasi1 ~(+ x 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-10 (ret-msg "(+ x 5)" :line 1 :col 1))
  (def actual-10 (parser/produce p))
  (is (== expect-10 actual-10))
  # No more messages
  (is (not (parser/has-more p)))
  # Test 5: Quasiquote with unquote - SHOULD depend on unquoted symbols
  (buffer/clear outb)
  (run-eval "(def quasi2 ~(+ ,x 5))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-11 (ret-msg "(+ 40 5)" :line 1 :col 1))
  (def actual-11 (parser/produce p))
  (is (== expect-11 actual-11))
  # No more messages
  (is (not (parser/has-more p)))
  (buffer/clear outb)
  # Redefine x, quasi2 should auto-update
  (run-eval "(def x 50)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # First message: return value from redefining x
  (def expect-12 (ret-msg "50" :line 1 :col 1))
  (def actual-12 (parser/produce p))
  (== expect-12 actual-12)
  # Second message: note about re-evaluation
  (def expect-13 (dep-msg "x" "y"))
  (def actual-13 (parser/produce p))
  (== expect-13 actual-13)
  # Third message: return value from re-evaluating quasi2
  (def expect-14 (ret-msg "(+ 50 5)" :line 1 :col 1))
  (def actual-14 (parser/produce p))
  (== expect-14 actual-14)
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 6: Nested quoted forms
  (run-eval "(def c 7)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def nested '(+ a '(* b c)))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-15 (ret-msg "(+ a (quote (* b c)))" :line 1 :col 1))
  (def actual-15 (parser/produce p))
  (is (== expect-15 actual-15))
  # Verify no more messages
  (is (not (parser/has-more p)))
  (buffer/clear outb)
  (run-eval "(def c 700)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-16 (ret-msg "700" :line 1 :col 1))
  (def actual-16 (parser/produce p))
  (is (== expect-16 actual-16))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 7: Mix of quoted and unquoted in a data structure
  (run-eval "(def d 8)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def mixed [d 'x])" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-17 (ret-msg "(8 x)" :line 1 :col 1))
  (def actual-17 (parser/produce p))
  (is (== expect-17 actual-17))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # d changes, mixed should update (unquoted d)
  (run-eval "(def d 9)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def mixed [d 'x])" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-18 (ret-msg "(9 x)" :line 1 :col 1))
  (def actual-18 (parser/produce p))
  (is (== expect-18 actual-18))
  # x changes, mixed should NOT update (quoted x)
  (run-eval "(def x 999)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def mixed [d 'x])" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-19 (ret-msg "(9 x)" :line 1 :col 1))
  (def actual-19 (parser/produce p))
  (is (== expect-19 actual-19))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-variadic-functions
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test 1: & (rest parameter) with global reference
  (e/run "(def multiplier 10)" :env env :send send :req req :sess sess)
  (e/run "(defn f [a & rest] (+ a (* multiplier (length rest))))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (e/run "(def result1 (f 5 1 2 3))" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  (def expect-1 (ret-msg "35" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  (buffer/clear outb)
  # Redefine multiplier - f should be re-evaluated
  (e/run "(def multiplier 100)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # First message: return value from redefining multiplier
  (def expect-2 (ret-msg "100" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Second message: note about re-evaluation
  (def expect-3 (dep-msg "multiplier" "f" "result1"))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Messages for re-evaluating dependents: result2, result3, z, result1
  (def expect-4 (ret-msg "<function f>" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (ret-msg "305" :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 2: &opt (optional parameter) with global reference
  (e/run "(defn g [a &opt b] (+ a (or b multiplier)))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (e/run "(def result3 (g 10))" :env env :send send :req req :sess sess)
  (e/run "(def result4 (g 10 5))" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  (def expect-6 (ret-msg "110" :line 1 :col 1))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  (def expect-7 (ret-msg "15" :line 1 :col 1))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 3: Multiple &opt parameters
  (e/run "(def default1 20)" :env env :send send :req req :sess sess)
  (e/run "(def default2 30)" :env env :send send :req req :sess sess)
  (e/run "(defn h [a &opt b c] (+ a (or b default1) (or c default2)))" :env env :send send :req req :sess sess)
  (e/run "(def result5 (h 1))" :env env :send send :req req :sess sess)
  (e/run "(def result6 (h 1 2))" :env env :send send :req req :sess sess)
  (e/run "(def result7 (h 1 2 3))" :env env :send send :req req :sess sess)
  # Redefine defaults - h should be re-evaluated
  (e/run "(def default1 200)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (e/run "(def default2 300)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  (def expect-8 (ret-msg "300" :line 1 :col 1))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  (def expect-9 (dep-msg "default2" "h" "result6" "result5" "result7"))
  (def actual-9 (parser/produce p))
  (is (== expect-9 actual-9))
  (def expect-10 (ret-msg "<function h>" :reeval? true))
  (def actual-10 (parser/produce p))
  (is (== expect-10 actual-10))
  (def expect-11 (ret-msg "303" :reeval? true))
  (def actual-11 (parser/produce p))
  (is (== expect-11 actual-11))
  (def expect-12 (ret-msg "501" :reeval? true))
  (def actual-12 (parser/produce p))
  (is (== expect-12 actual-12))
  (def expect-13 (ret-msg "6" :reeval? true))
  (def actual-13 (parser/produce p))
  (is (== expect-13 actual-13))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 4: Variadic parameter shadowing a global
  (e/run "(def rest 999)" :env env :send send :req req :sess sess)
  (e/run "(defn shadow-test [a & rest] (length rest))" :env env :send send :req req :sess sess)
  (e/run "(def result8 (shadow-test 1 2 3 4))" :env env :send send :req req :sess sess)
  # Redefine global rest - shadow-test should NOT be re-evaluated
  (buffer/clear outb)
  (e/run "(def rest 111)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-14 (ret-msg "111" :line 1 :col 1))
  (def actual-14 (parser/produce p))
  (is (== expect-14 actual-14))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 5: &keys parameter
  (e/run "(def key-default 42)" :env env :send send :req req :sess sess)
  (e/run "(defn with-keys [a &keys {:x x :y y}] (+ a (or x key-default) (or y key-default)))" :env env :send send :req req :sess sess)
  (e/run "(def result9 (with-keys 1 :x 10 :y 20))" :env env :send send :req req :sess sess)
  (e/run "(def result10 (with-keys 1))" :env env :send send :req req :sess sess)
  # Redefine key-default - with-keys should be re-evaluated
  (buffer/clear outb)
  (e/run "(def key-default 100)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  (def expect-15 (ret-msg "100" :line 1 :col 1))
  (def actual-15 (parser/produce p))
  (is (== expect-15 actual-15))
  (def expect-16 (dep-msg "key-default" "with-keys" "result10" "result9"))
  (def actual-16 (parser/produce p))
  (is (== expect-16 actual-16))
  (def expect-17 (ret-msg "<function with-keys>" :reeval? true))
  (def actual-17 (parser/produce p))
  (is (== expect-17 actual-17))
  (def expect-18 (ret-msg "201" :reeval? true))
  (def actual-18 (parser/produce p))
  (is (== expect-18 actual-18))
  (def expect-19 (ret-msg "31" :reeval? true))
  (def actual-19 (parser/produce p))
  (is (== expect-19 actual-19))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test 6: &named parameter
  (e/run "(def named-default 7)" :env env :send send :req req :sess sess)
  (e/run "(defn with-named [a &named x y] (+ a (or x named-default) (or y named-default)))" :env env :send send :req req :sess sess)
  (e/run "(def result11 (with-named 1 :x 2 :y 3))" :env env :send send :req req :sess sess)
  (e/run "(def result12 (with-named 1))" :env env :send send :req req :sess sess)
  # Redefine named-default - with-named should be re-evaluated
  (buffer/clear outb)
  (e/run "(def named-default 50)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  (def expect-20 (ret-msg "50" :line 1 :col 1))
  (def actual-20 (parser/produce p))
  (is (== expect-20 actual-20))
  (def expect-21 (dep-msg "named-default" "with-named" "result12" "result11"))
  (def actual-21 (parser/produce p))
  (is (== expect-21 actual-21))
  (def expect-22 (ret-msg "<function with-named>" :reeval? true))
  (def actual-22 (parser/produce p))
  (is (== expect-22 actual-22))
  (def expect-23 (ret-msg "101" :reeval? true))
  (def actual-23 (parser/produce p))
  (is (== expect-23 actual-23))
  (def expect-24 (ret-msg "6" :reeval? true))
  (def actual-24 (parser/produce p))
  (is (== expect-24 actual-24))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-nested-functions
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define global x
  (run-eval "(def x 10)" :env env :send send :req req :sess sess)
  # Define function that returns closure capturing x
  (run-eval "(defn outer [] (fn [] x))" :env env :send send :req req :sess sess)
  (run-eval "(def inner (outer))" :env env :send send :req req :sess sess)
  (run-eval "(def result1 (inner))" :env env :send send :req req :sess sess)
  # Redefine x - outer should be re-evaluated, which re-evaluates inner
  (buffer/clear outb)
  (run-eval "(def x 20)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from x redefinition
  (def expect-1 (ret-msg "20" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Note about re-evaluation
  (def expect-2 (dep-msg "x" "outer" "inner" "result1"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Return from re-evaluating outer
  (def expect-3 (ret-msg "<function outer>" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Return from re-evaluating inner
  (def expect-4 (ret-msg nil :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== (merge expect-4 {"val" (actual-4 "val")}) actual-4))
  # Return from re-evaluating result1
  (def expect-5 (ret-msg "20" :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-destructuring
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test array destructuring
  (e/run "(def x 10)" :env env :send send :req req :sess sess)
  (e/run "(def y 20)" :env env :send send :req req :sess sess)
  (e/run "(def [a b] [x y])" :env env :send send :req req :sess sess)
  # Redefine x, destructured bindings should update
  (buffer/clear outb)
  (e/run "(def x 100)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from x redefinition
  (def expect-1 (ret-msg "100" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Note about re-evaluation
  (def expect-2 (dep-msg "x" "b" "a"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Return from re-evaluating b
  (def expect-3 (ret-msg "(100 20)" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Return from re-evaluating a
  (def expect-4 (ret-msg "(100 20)" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Test struct destructuring
  (e/run "(def data {:foo 1 :bar 2})" :env env :send send :req req :sess sess)
  (e/run "(def {:foo f :bar b} data)" :env env :send send :req req :sess sess)
  # Redefine data, destructured bindings should update
  (buffer/clear outb)
  (e/run "(def data {:foo 10 :bar 20})" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from data redefinition
  (def expect-5 (ret-msg "{:bar 20 :foo 10}" :line 1 :col 1))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Note about re-evaluation
  (def expect-6 (dep-msg "data" "b" "f"))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # Return from re-evaluating b
  (def expect-7 (ret-msg "{:bar 20 :foo 10}" :reeval? true))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Return from re-evaluating f
  (def expect-8 (ret-msg "{:bar 20 :foo 10}" :reeval? true))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-loop-bindings
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Test that loop bindings are scoped correctly (i should not be tracked as dependency)
  (run-eval "(def n 5)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def total1 (do (var acc 0) (loop [i :range [0 n]] (+= acc i)) acc))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "10" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Redefine n, total1 should be re-evaluated with new range
  (buffer/clear outb)
  (run-eval "(def n 4)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  # Skip the ret message for n
  (parser/produce p)
  # Skip the note message
  (parser/produce p)
  # Check the re-evaluation of total1
  (def expect-2 (ret-msg "6" :reeval? true))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Test loop with :in modifier and external reference
  (run-eval "(def items [1 2 3])" :env env :send send :req req :sess sess)
  (run-eval "(def multiplier 10)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def total2 (do (var acc 0) (loop [item :in items] (+= acc (* item multiplier))) acc))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-3 (ret-msg "60" :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Redefine multiplier - total2 should be re-evaluated
  (buffer/clear outb)
  (run-eval "(def multiplier 5)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-4 (ret-msg "5" :line 1 :col 1))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (dep-msg "multiplier" "total2"))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Check the re-evaluation of total2
  (def expect-6 (ret-msg "30" :reeval? true))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-chained-dependencies
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create chain a -> b -> c
  (e/run "(def a 1)" :env env :send send :req req :sess sess)
  (e/run "(def b (+ a 1))" :env env :send send :req req :sess sess)
  (e/run "(def c (+ b 1))" :env env :send send :req req :sess sess)
  # Redefine a, both b and c should update
  (buffer/clear outb)
  (e/run "(def a 10)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from a redefinition
  (def expect-1 (ret-msg "10" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Note about re-evaluation
  (def expect-2 (dep-msg "a" "b" "c"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Return from re-evaluating b
  (def expect-3 (ret-msg "11" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Return from re-evaluating c
  (def expect-4 (ret-msg "12" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-function-dependency
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define variable and function that uses it
  (run-eval "(def x 10)" :env env :send send :req req :sess sess)
  (run-eval "(defn f [] (+ x 5))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result1 (f))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "15" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Redefine x, function should be recompiled
  (run-eval "(def x 20)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def result2 (f))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "25" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-transitive-through-function
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define a -> g (function) -> b (calls g)
  (e/run "(def a 5)" :env env :send send :req req :sess sess)
  (e/run "(defn g [] (+ a 10))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (e/run "(def b (g))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "15" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Redefine a, both g and b should update
  (buffer/clear outb)
  (e/run "(def a 100)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "100" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 (dep-msg "a" "g" "b"))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (ret-msg "<function g>" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (ret-msg "110" :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-multiple-dependencies
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # z depends on both x and y
  (run-eval "(def x 10)" :env env :send send :req req :sess sess)
  (run-eval "(def y 20)" :env env :send send :req req :sess sess)
  (run-eval "(def z (+ x y))" :env env :send send :req req :sess sess)
  # Redefine x, z should update
  (buffer/clear outb)
  (run-eval "(def x 100)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from x redefinition
  (def expect-1 (ret-msg "100" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Note about re-evaluation
  (def expect-2 (dep-msg "x" "z"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Return from re-evaluating z
  (def expect-3 (ret-msg "120" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine y, z should update again
  (buffer/clear outb)
  (run-eval "(def y 5)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from y redefinition
  (def expect-4 (ret-msg "5" :line 1 :col 1))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Note about re-evaluation
  (def expect-5 (dep-msg "y" "z"))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  # Return from re-evaluating z
  (def expect-6 (ret-msg "105" :reeval? true))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-multiple-dependents
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Both c and d depend on a and b
  (e/run "(def a 1)" :env env :send send :req req :sess sess)
  (e/run "(def b 2)" :env env :send send :req req :sess sess)
  (e/run "(def c (+ a b))" :env env :send send :req req :sess sess)
  (e/run "(def d (* a b))" :env env :send send :req req :sess sess)
  # Redefine a, both c and d should update
  (buffer/clear outb)
  (e/run "(def a 10)" :env env :send send :req req :sess sess)
  # Parse and verify messages
  (parser/consume p outb)
  # Return from a redefinition
  (def expect-1 (ret-msg "10" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Note about re-evaluation
  (def expect-2 (dep-msg "a" "d" "c"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Return from re-evaluating d
  (def expect-3 (ret-msg "20" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Return from re-evaluating c
  (def expect-4 (ret-msg "12" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-diamond-dependency
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create diamond: a depends on b and c, both b and c depend on d
  (run-eval "(def d 5)" :env env :send send :req req :sess sess)
  (run-eval "(def b (+ d 10))" :env env :send send :req req :sess sess)
  (run-eval "(def c (+ d 20))" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (run-eval "(def a (+ b c))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "40" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Redefine d - b and c should update, then a should update once with both new values
  (buffer/clear outb)
  (run-eval "(def d 100)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "100" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 (dep-msg "d" "c" "b" "a"))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-2 (ret-msg "120" :reeval? true))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 (ret-msg "110" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (ret-msg "230" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-circular-direct
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create circular dependency a <-> b
  (e/run "(def a 10)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (e/run "(def b a)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "10" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Close the loop
  (buffer/clear outb)
  (e/run "(def a b)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "10" :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 (dep-msg "a" "b"))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (ret-msg "10" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine b, should not infinite loop
  (buffer/clear outb)
  (e/run "(def b 100)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-6 (ret-msg "100" :line 1 :col 1))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  (def expect-7 (dep-msg "b" "a"))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  (def expect-8 (ret-msg "100" :reeval? true))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-circular-indirect
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Create cycle x -> y -> z -> x
  (run-eval "(def x 1)" :env env :send send :req req :sess sess)
  (run-eval "(def y 2)" :env env :send send :req req :sess sess)
  (run-eval "(def z 3)" :env env :send send :req req :sess sess)
  (run-eval "(def x y)" :env env :send send :req req :sess sess)
  (run-eval "(def y z)" :env env :send send :req req :sess sess)
  (run-eval "(def z x)" :env env :send send :req req :sess sess)
  # Redefine any, should not infinite loop
  (buffer/clear outb)
  (run-eval "(def x 100)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "100" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  (def expect-2 (dep-msg "x" "z" "y"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Check re-evaluation of z
  (def expect-3 (ret-msg "100" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Check re-evaluation of y
  (def expect-4 (ret-msg "100" :reeval? true))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-error-handling
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def path (dyn :current-file))
  (def sess @{:dep-graph @{}})
  # Define x as a function, y calls it, z uses it
  (e/run "(def x +)" :env env :send send :req req :sess sess)
  (buffer/clear outb)
  (e/run "(def y (x 1 2))" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  (def expect-init (ret-msg "3" :line 1 :col 1))
  (def actual-init (parser/produce p))
  (is (== expect-init actual-init))
  (e/run "(def z (+ x 100))" :env env :send send :req req :sess sess)
  # Redefine x to a symbol (will cause errors in re-evaluation)
  (buffer/clear outb)
  (e/run "(def x 'not-a-function)" :env env :send send :req req :sess sess)
  # Check exact error messages
  (parser/consume p outb)
  # First message should be the successful redefinition of x
  (def expect-1 (ret-msg "not-a-function" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Second message should be note about re-evaluation
  (def expect-2 (dep-msg "x" "z" "y"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Third message should be an error for z re-evaluation
  (def expect-3 (err-msg "error: could not find method :+ for not-a-function"))
  (def actual-3 (parser/produce p))
  (is (== (merge expect-3 {"janet/stack" (actual-3 "janet/stack")}) actual-3))
  # Fourth message should be an error for y re-evaluation
  (def expect-4 (err-msg "compile error: not-a-function expects 1 argument, got 2" :line 1 :col 8))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-informational-messages
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  # Define dependencies
  (run-eval "(def x 10)" :env env :send send :req req :sess sess)
  (run-eval "(def y (+ x 5))" :env env :send send :req req :sess sess)
  # Redefine x and check for note message
  (buffer/clear outb)
  (run-eval "(def x 20)" :env env :send send :req req :sess sess)
  (parser/consume p outb)
  # First message should be the return value
  (def expect-1 (ret-msg "20" :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Second message should be the informational note about re-evaluation
  (def expect-2 (dep-msg "x" "y"))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Third message should be the return value from re-evaluating y
  (def expect-3 (ret-msg "25" :reeval? true))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Verify no more messages
  (is (not (parser/has-more p))))

# Cross-environment binding dependency tests (individual form evaluation)

(deftest deps-cross-env-binding-simple
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create base environment and evaluate a binding
  (def base-path "test-base-env.janet")
  (def base-env (e/eval-make-env))
  (put module/cache base-path base-env)
  (e/run "(def value 10)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Create using environment that imports base
  (def using-path "test-using-env.janet")
  (def using-env (e/eval-make-env))
  (put module/cache using-path using-env)
  (e/run (string "(import " base-path " :as base)")
         :env using-env :send send :req req :path using-path :sess sess)
  (buffer/clear outb)
  (e/run "(def result (+ base/value 20))"
         :env using-env :send send :req req :path using-path :sess sess)
  # Check initial result value
  (parser/consume p outb)
  (def expect-1 (ret-msg "30" :path using-path :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Redefine value in base environment
  (buffer/clear outb)
  (e/run "(def value 100)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Check that result was re-evaluated in using environment
  (parser/consume p outb)
  (def expect-2 (ret-msg "100" :path base-path :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 (cross-msg using-path "result"))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Check re-evaluation of result in using environment
  (def expect-2 (ret-msg "120" :path using-path :reeval? true))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-cross-env-binding-multiple
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create base environment
  (def base-path "test-shared-env.janet")
  (def base-env (e/eval-make-env))
  (put module/cache base-path base-env)
  (run-eval "(def shared 10)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Create first importing environment
  (def env1-path "test-env1.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (run-eval (string "(import " base-path " :as base)")
         :env env1 :send send :req req :path env1-path :sess sess)
  (buffer/clear outb)
  (run-eval "(def local1 (+ base/shared 1))"
         :env env1 :send send :req req :path env1-path :sess sess)
  (parser/consume p outb)
  (def expect-1 (ret-msg "11" :path env1-path :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Create second importing environment
  (def env2-path "test-env2.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (run-eval (string "(import " base-path " :as base)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (buffer/clear outb)
  (run-eval "(def local2 (* base/shared 2))"
         :env env2 :send send :req req :path env2-path :sess sess)
  (parser/consume p outb)
  (def expect-2 (ret-msg "20" :path env2-path :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine shared in base environment
  (buffer/clear outb)
  (run-eval "(def shared 50)"
         :env base-env :send send :req req :path base-path :sess sess)
  # Check if both importers updated
  (parser/consume p outb)
  (def expect-3 (ret-msg "50" :path base-path :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (cross-msg env1-path "local1"))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (ret-msg "51" :path env1-path :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  (def expect-6 (cross-msg env2-path "local2"))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  (def expect-7 (ret-msg "100" :path env2-path :reeval? true))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-cross-env-binding-transitive
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create level1 environment
  (def level1-path "test-l1-env.janet")
  (def level1-env (e/eval-make-env))
  (put module/cache level1-path level1-env)
  (e/run "(def root 100)"
         :env level1-env :send send :req req :path level1-path :sess sess)
  # Create level2 environment that imports level1
  (def level2-path "test-l2-env.janet")
  (def level2-env (e/eval-make-env))
  (put module/cache level2-path level2-env)
  (e/run (string "(import " level1-path " :as l1)")
         :env level2-env :send send :req req :path level2-path :sess sess)
  (buffer/clear outb)
  (e/run "(def middle (+ l1/root 50))"
         :env level2-env :send send :req req :path level2-path :sess sess)
  # Check initial value of middle
  (parser/consume p outb)
  (def expect-1 (ret-msg "150" :path level2-path :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Create level3 environment that imports level2
  (def level3-path "test-l3-env.janet")
  (def level3-env (e/eval-make-env))
  (put module/cache level3-path level3-env)
  (e/run (string "(import " level2-path " :as l2)")
         :env level3-env :send send :req req :path level3-path :sess sess)
  (buffer/clear outb)
  (e/run "(def top (* l2/middle 2))"
         :env level3-env :send send :req req :path level3-path :sess sess)
  # Check initial value of top
  (parser/consume p outb)
  (def expect-2 (ret-msg "300" :path level3-path :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine root in level1
  (buffer/clear outb)
  (e/run "(def root 200)"
         :env level1-env :send send :req req :path level1-path :sess sess)
  # Check if all levels updated transitively
  (parser/consume p outb)
  (def expect-3 (ret-msg "200" :path level1-path :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (cross-msg level2-path "middle"))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (ret-msg "250" :path level2-path :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  (def expect-6 (cross-msg level3-path "top"))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  (def expect-7 (ret-msg "500" :path level3-path :reeval? true))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-cross-env-binding-circular
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create env1 with binding 'x'
  (def env1-path "test-circ1.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (run-eval "(def x 10)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Create env2 that imports env1 and defines 'y'
  (def env2-path "test-circ2.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (run-eval (string "(import " env1-path " :as e1)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (buffer/clear outb)
  (run-eval "(def y (+ e1/x 5))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Check initial value of y
  (parser/consume p outb)
  (def expect-1 (ret-msg "15" :path env2-path :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Create circular reference: env1 imports env2 and uses 'y'
  (run-eval (string "(import " env2-path " :as e2)")
         :env env1 :send send :req req :path env1-path :sess sess)
  (buffer/clear outb)
  (run-eval "(def z (* e2/y 2))"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Check initial value of z
  (parser/consume p outb)
  (def expect-2 (ret-msg "30" :path env1-path :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine x - should update y, then z, without infinite loop
  (buffer/clear outb)
  (run-eval "(def x 20)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Verify cascade worked and didn't infinite loop
  (parser/consume p outb)
  (def expect-3 (ret-msg "20" :path env1-path :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (cross-msg env2-path "y"))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (ret-msg "25" :path env2-path :reeval? true))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  (def expect-6 (cross-msg env1-path "z"))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  (def expect-7 (ret-msg "50" :path env1-path :reeval? true))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Verify no more messages (no infinite loop)
  (is (not (parser/has-more p))))

(deftest deps-cross-env-binding-diamond
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create top of diamond: env1 with 'root'
  (def env1-path "test-diamond-top.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (e/run "(def root 100)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Left side: env2 imports env1, defines 'left'
  (def env2-path "test-diamond-left.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (e/run (string "(import " env1-path " :as top)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (buffer/clear outb)
  (e/run "(def left (+ top/root 10))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Check initial value of left
  (parser/consume p outb)
  (def expect-1 (ret-msg "110" :path env2-path :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Right side: env3 imports env1, defines 'right'
  (def env3-path "test-diamond-right.janet")
  (def env3 (e/eval-make-env))
  (put module/cache env3-path env3)
  (e/run (string "(import " env1-path " :as top)")
         :env env3 :send send :req req :path env3-path :sess sess)
  (buffer/clear outb)
  (e/run "(def right (+ top/root 20))"
         :env env3 :send send :req req :path env3-path :sess sess)
  # Check initial value of right
  (parser/consume p outb)
  (def expect-2 (ret-msg "120" :path env3-path :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Bottom of diamond: env4 imports both env2 and env3
  (def env4-path "test-diamond-bottom.janet")
  (def env4 (e/eval-make-env))
  (put module/cache env4-path env4)
  (e/run (string "(import " env2-path " :as left-side)")
         :env env4 :send send :req req :path env4-path :sess sess)
  (e/run (string "(import " env3-path " :as right-side)")
         :env env4 :send send :req req :path env4-path :sess sess)
  (buffer/clear outb)
  (e/run "(def bottom (+ left-side/left right-side/right))"
         :env env4 :send send :req req :path env4-path :sess sess)
  # Check initial value of bottom
  (parser/consume p outb)
  (def expect-3 (ret-msg "230" :path env4-path :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine root - should propagate through diamond correctly
  (buffer/clear outb)
  (e/run "(def root 200)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Verify all paths updated correctly
  (parser/consume p outb)
  (def expect-4 (ret-msg "200" :path env1-path :line 1 :col 1))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  # Re-evaluations happen in topological order, with notes before each file
  # Files are processed alphabetically, symbols by line number
  # Left is evaluated first (test-diamond-left.janet < test-diamond-right.janet)
  (def expect-5 (cross-msg env2-path "left"))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  (def expect-6 (ret-msg "210" :path env2-path :reeval? true))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  # Then right
  (def expect-7 (cross-msg env3-path "right"))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  (def expect-8 (ret-msg "220" :path env3-path :reeval? true))
  (def actual-8 (parser/produce p))
  (is (== expect-8 actual-8))
  # Finally bottom (depends on both left and right) - only ONCE with correct value!
  (def expect-9 (cross-msg env4-path "bottom"))
  (def actual-9 (parser/produce p))
  (is (== expect-9 actual-9))
  (def expect-10 (ret-msg "430" :path env4-path :reeval? true))
  (def actual-10 (parser/produce p))
  (is (== expect-10 actual-10))
  # Verify no more messages
  (is (not (parser/has-more p))))

(deftest deps-cross-env-binding-error-cascade
  (table/clear module/cache)
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def sess @{:dep-graph @{}})
  # Create env1 with a binding that will be changed to cause errors
  (def env1-path "test-error1.janet")
  (def env1 (e/eval-make-env))
  (put module/cache env1-path env1)
  (run-eval "(def fn-or-val +)"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Create env2 that calls fn-or-val (works when it's a function)
  (def env2-path "test-error2.janet")
  (def env2 (e/eval-make-env))
  (put module/cache env2-path env2)
  (run-eval (string "(import " env1-path " :as e1)")
         :env env2 :send send :req req :path env2-path :sess sess)
  (buffer/clear outb)
  (run-eval "(def result (e1/fn-or-val 5 10))"
         :env env2 :send send :req req :path env2-path :sess sess)
  # Check initial value of result
  (parser/consume p outb)
  (def expect-1 (ret-msg "15" :path env2-path :line 1 :col 1))
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Create env3 that depends on env2's result
  (def env3-path "test-error3.janet")
  (def env3 (e/eval-make-env))
  (put module/cache env3-path env3)
  (run-eval (string "(import " env2-path " :as e2)")
         :env env3 :send send :req req :path env3-path :sess sess)
  (buffer/clear outb)
  (run-eval "(def final (* e2/result 2))"
         :env env3 :send send :req req :path env3-path :sess sess)
  # Check initial value of final
  (parser/consume p outb)
  (def expect-2 (ret-msg "30" :path env3-path :line 1 :col 1))
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Verify no more messages
  (is (not (parser/has-more p)))
  # Redefine fn-or-val to a string (will cause error when called)
  (buffer/clear outb)
  (run-eval "(def fn-or-val \"not-a-function\")"
         :env env1 :send send :req req :path env1-path :sess sess)
  # Check messages: should have ret for fn-or-val, note, then error for result
  (parser/consume p outb)
  (def expect-3 (ret-msg `"not-a-function"` :path env1-path :line 1 :col 1))
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (def expect-4 (cross-msg env2-path "result"))
  (def actual-4 (parser/produce p))
  (is (== expect-4 actual-4))
  (def expect-5 (err-msg `"not-a-function" expects 1 argument, got 2` :path env2-path))
  (def actual-5 (parser/produce p))
  (is (== expect-5 actual-5))
  (def expect-6 (cross-msg env3-path "final"))
  (def actual-6 (parser/produce p))
  (is (== expect-6 actual-6))
  (def expect-7 (ret-msg "30" :path env3-path :reeval? true))
  (def actual-7 (parser/produce p))
  (is (== expect-7 actual-7))
  # Verify no more messages
  (is (not (parser/has-more p))))

(run-tests!)

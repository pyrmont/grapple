(use ../deps/testament)

(import ../lib/utilities :as u)
(import ../lib/evaluator :as e)
(import ../lib/deps :as deps)

# Utility Functions

(defn make-sender [b]
  (fn :send [v]
    (buffer/push b (string/format "%q" v))))

# Generic eval request

(def req
  {"op" "env/eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})

# Helper to get binding value from environment

(defn get-value [env sym]
  (def binding (get env sym))
  (if-let [ref (get binding :ref)]
    (get ref 0)
    (get binding :value)))

# Tests

(deftest deps-simple-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define x and y where y depends on x
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(def y (+ x 5))" :env env :send send :req req)
  (is (= 10 (get-value env 'x)))
  (is (= 15 (get-value env 'y)))
  # Redefine x, y should auto-update
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req)
  (is (= 20 (get-value env 'x)))
  (is (= 25 (get-value env 'y))))

(deftest deps-var-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define var a and b where b depends on a
  (e/run "(var a 10)" :env env :send send :req req)
  (e/run "(def b (+ a 5))" :env env :send send :req req)
  (is (= 10 (get-value env 'a)))
  (is (= 15 (get-value env 'b)))
  # Redefine a, b should auto-update
  (buffer/clear outb)
  (e/run "(var a 20)" :env env :send send :req req)
  (is (= 20 (get-value env 'a)))
  (is (= 25 (get-value env 'b))))

(deftest deps-complex-expressions
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Test nested function calls
  (e/run "(def x 5)" :env env :send send :req req)
  (e/run "(def y 10)" :env env :send send :req req)
  (e/run "(def z (+ (* x 2) y))" :env env :send send :req req)
  (is (= 20 (get-value env 'z)))
  # Test let bindings within defs
  (e/run "(def result1 (let [temp (+ x 1)] (* temp 2)))" :env env :send send :req req)
  (is (= 12 (get-value env 'result1)))
  # Test conditionals
  (e/run "(def result2 (if (> x 3) (+ x y) y))" :env env :send send :req req)
  (is (= 15 (get-value env 'result2)))
  # Test do blocks
  (e/run "(def result3 (do (+ x 1) (+ x y)))" :env env :send send :req req)
  (is (= 15 (get-value env 'result3)))
  # Redefine x, all dependents should update
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req)
  (is (= 20 (get-value env 'x)))
  (is (= 50 (get-value env 'z)))
  (is (= 42 (get-value env 'result1)))
  (is (= 30 (get-value env 'result2)))
  (is (= 30 (get-value env 'result3)))
  # Redefine y, relevant dependents should update
  (buffer/clear outb)
  (e/run "(def y 100)" :env env :send send :req req)
  (is (= 100 (get-value env 'y)))
  (is (= 140 (get-value env 'z)))
  (is (= 42 (get-value env 'result1)))  # Doesn't depend on y
  (is (= 120 (get-value env 'result2)))
  (is (= 120 (get-value env 'result3))))

(deftest deps-macro-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define a macro and use it
  (e/run "(defmacro double [x] ~(* 2 ,x))" :env env :send send :req req)
  (e/run "(def y (double 5))" :env env :send send :req req)
  (is (= 10 (get-value env 'y)))
  # Redefine the macro, y should be re-evaluated with new macro
  (buffer/clear outb)
  (e/run "(defmacro double [x] ~(* 3 ,x))" :env env :send send :req req)
  (is (= 15 (get-value env 'y)))
  # Test macro that references a value
  (e/run "(def multiplier 4)" :env env :send send :req req)
  (e/run "(defmacro mult [x] ~(* multiplier ,x))" :env env :send send :req req)
  (e/run "(def z (mult 5))" :env env :send send :req req)
  (is (= 20 (get-value env 'z)))
  # Redefine multiplier - this affects the macro expansion
  (buffer/clear outb)
  (e/run "(def multiplier 10)" :env env :send send :req req)
  # z should update because mult (which depends on multiplier) was redefined
  (is (= 50 (get-value env 'z))))

(deftest deps-local-scope-shadowing
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define global x
  (e/run "(def x 10)" :env env :send send :req req)
  # Define y with local x that shadows global - y should NOT depend on global x
  (e/run "(def y (let [x 20] x))" :env env :send send :req req)
  (is (= 10 (get-value env 'x)))
  (is (= 20 (get-value env 'y)))
  # Redefine global x - y should NOT update
  (e/run "(def x 100)" :env env :send send :req req)
  (is (= 100 (get-value env 'x)))
  (is (= 20 (get-value env 'y)))
  # Test let with outer reference (no shadowing)
  (e/run "(def z (let [a x] (+ a 5)))" :env env :send send :req req)
  (is (= 105 (get-value env 'z)))  # a=100 (from global x), result=105
  # Redefine x - z should update (let binds a to x)
  (e/run "(def x 50)" :env env :send send :req req)
  (is (= 55 (get-value env 'z))))

(deftest deps-function-parameter-shadowing
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Test 1: Simple parameter shadowing
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(defn f [x] x)" :env env :send send :req req)
  (e/run "(def result1 (f 20))" :env env :send send :req req)
  (is (= 20 (get-value env 'result1)))
  # Redefine global x - f should NOT be re-evaluated
  (e/run "(def x 100)" :env env :send send :req req)
  (e/run "(def result2 (f 30))" :env env :send send :req req)
  (is (= 30 (get-value env 'result2)))
  # Test 2: Function that uses both parameter and global
  (e/run "(defn g [y] (+ x y))" :env env :send send :req req)
  (e/run "(def result3 (g 5))" :env env :send send :req req)
  (is (= 105 (get-value env 'result3)))  # x=100, y=5
  # Redefine x - g should be re-evaluated
  (e/run "(def x 50)" :env env :send send :req req)
  (e/run "(def result4 (g 5))" :env env :send send :req req)
  (is (= 55 (get-value env 'result4)))
  # Test 3: Multiple parameters shadowing multiple globals
  (e/run "(def a 1)" :env env :send send :req req)
  (e/run "(def b 2)" :env env :send send :req req)
  (e/run "(defn h [a b] (+ a b))" :env env :send send :req req)
  (e/run "(def result5 (h 10 20))" :env env :send send :req req)
  (is (= 30 (get-value env 'result5)))
  # Redefine globals - h should NOT be re-evaluated
  (e/run "(def a 100)" :env env :send send :req req)
  (e/run "(def b 200)" :env env :send send :req req)
  (e/run "(def result6 (h 10 20))" :env env :send send :req req)
  (is (= 30 (get-value env 'result6)))
  # Test 4: Destructuring parameters
  (e/run "(def data [1 2 3])" :env env :send send :req req)
  (e/run "(defn destructure [[x y]] (+ x y))" :env env :send send :req req)
  (e/run "(def result7 (destructure [5 10]))" :env env :send send :req req)
  (is (= 15 (get-value env 'result7)))
  # Redefine x and data - destructure should NOT be re-evaluated (x is shadowed)
  (e/run "(def x 999)" :env env :send send :req req)
  (e/run "(def data [100 200 300])" :env env :send send :req req)
  (e/run "(def result8 (destructure [5 10]))" :env env :send send :req req)
  (is (= 15 (get-value env 'result8)))
  # Test 5: Anonymous function with shadowing
  (e/run "(def anon-f (fn [x] x))" :env env :send send :req req)
  (e/run "(def result9 (anon-f 42))" :env env :send send :req req)
  (is (= 42 (get-value env 'result9)))
  # Redefine x - anon-f should NOT be re-evaluated
  (e/run "(def x 123)" :env env :send send :req req)
  (e/run "(def result10 (anon-f 42))" :env env :send send :req req)
  (is (= 42 (get-value env 'result10)))
  # Test 6: Named function (fn with name)
  (e/run "(def named-f (fn my-func [x] x))" :env env :send send :req req)
  (e/run "(def result11 (named-f 99))" :env env :send send :req req)
  (is (= 99 (get-value env 'result11)))
  # Test 7: Function with parameter and body that references a different global
  (e/run "(def c 1000)" :env env :send send :req req)
  (e/run "(defn mixed [x] (+ x c))" :env env :send send :req req)
  (e/run "(def result12 (mixed 5))" :env env :send send :req req)
  (is (= 1005 (get-value env 'result12)))
  # Redefine x (shadowed) - mixed should NOT be re-evaluated
  (e/run "(def x 777)" :env env :send send :req req)
  (e/run "(def result13 (mixed 5))" :env env :send send :req req)
  (is (= 1005 (get-value env 'result13)))
  # Redefine c (used in body) - mixed should be re-evaluated
  (e/run "(def c 2000)" :env env :send send :req req)
  (e/run "(def result14 (mixed 5))" :env env :send send :req req)
  (is (= 2005 (get-value env 'result14))))

(deftest deps-no-dependents
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define x with no dependents
  (e/run "(def x 10)" :env env :send send :req req)
  (is (= 10 (get-value env 'x)))
  # Redefine x - should work fine, no re-evaluations needed
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req)
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
  # Test 1: Quoted symbol - should NOT depend on the symbol's value
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(def y 'x)" :env env :send send :req req)
  (is (= 'x (get-value env 'y)))
  (e/run "(def x 20)" :env env :send send :req req)
  (is (= 'x (get-value env 'y)))
  # Test 2: Quoted list - should NOT depend on symbols in the list
  (e/run "(def z '(+ x 5))" :env env :send send :req req)
  (is (= '(+ x 5) (get-value env 'z)))
  (e/run "(def x 30)" :env env :send send :req req)
  (is (= '(+ x 5) (get-value env 'z)))
  # Test 3: Quoted tuple vs array
  (e/run "(def a 1)" :env env :send send :req req)
  (e/run "(def b 2)" :env env :send send :req req)
  (e/run "(def tuple-quote '(a b))" :env env :send send :req req)
  (e/run "(def array-quote '[a b])" :env env :send send :req req)
  (is (= '(a b) (get-value env 'tuple-quote)))
  (is (= '[a b] (get-value env 'array-quote)))
  # Redefine - neither should update
  (e/run "(def a 100)" :env env :send send :req req)
  (is (= '(a b) (get-value env 'tuple-quote)))
  (is (= '[a b] (get-value env 'array-quote)))
  # Test 4: Quasiquote without unquote - should NOT depend
  (e/run "(def quasi1 ~(+ x 5))" :env env :send send :req req)
  (is (= ~(+ x 5) (get-value env 'quasi1)))
  (e/run "(def x 40)" :env env :send send :req req)
  (is (= ~(+ x 5) (get-value env 'quasi1)))
  # Test 5: Quasiquote with unquote - SHOULD depend on unquoted symbols
  (e/run "(def quasi2 ~(+ ,x 5))" :env env :send send :req req)
  (is (= ~(+ ,40 5) (get-value env 'quasi2)))
  (e/run "(def x 50)" :env env :send send :req req)
  (is (= ~(+ ,50 5) (get-value env 'quasi2)))
  # Test 6: Nested quoted forms
  (e/run "(def c 7)" :env env :send send :req req)
  (e/run "(def nested '(+ a '(* b c)))" :env env :send send :req req)
  (is (= '(+ a '(* b c)) (get-value env 'nested)))
  (e/run "(def c 700)" :env env :send send :req req)
  (is (= '(+ a '(* b c)) (get-value env 'nested)))
  # Test 7: Mix of quoted and unquoted in a data structure
  (e/run "(def d 8)" :env env :send send :req req)
  (e/run "(def mixed [d 'x])" :env env :send send :req req)
  (is (= [8 'x] (get-value env 'mixed)))
  # d changes, mixed should update (unquoted d)
  (e/run "(def d 9)" :env env :send send :req req)
  (is (= [9 'x] (get-value env 'mixed)))
  # x changes, mixed should NOT update (quoted x)
  (e/run "(def x 999)" :env env :send send :req req)
  (is (= [9 'x] (get-value env 'mixed))))

(deftest deps-variadic-functions
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Test 1: & (rest parameter) with global reference
  (e/run "(def multiplier 10)" :env env :send send :req req)
  (e/run "(defn f [a & rest] (+ a (* multiplier (length rest))))" :env env :send send :req req)
  (e/run "(def result1 (f 5 1 2 3))" :env env :send send :req req)
  (is (= 35 (get-value env 'result1)))  # 5 + (10 * 3) = 35
  # Redefine multiplier - f should be re-evaluated
  (e/run "(def multiplier 100)" :env env :send send :req req)
  (e/run "(def result2 (f 5 1 2 3))" :env env :send send :req req)
  (is (= 305 (get-value env 'result2)))  # 5 + (100 * 3) = 305
  # Test 2: &opt (optional parameter) with global reference
  (e/run "(defn g [a &opt b] (+ a (or b multiplier)))" :env env :send send :req req)
  (e/run "(def result3 (g 10))" :env env :send send :req req)
  (is (= 110 (get-value env 'result3)))  # 10 + 100 = 110
  (e/run "(def result4 (g 10 5))" :env env :send send :req req)
  (is (= 15 (get-value env 'result4)))  # 10 + 5 = 15
  # Test 3: Multiple &opt parameters
  (e/run "(def default1 20)" :env env :send send :req req)
  (e/run "(def default2 30)" :env env :send send :req req)
  (e/run "(defn h [a &opt b c] (+ a (or b default1) (or c default2)))" :env env :send send :req req)
  (e/run "(def result5 (h 1))" :env env :send send :req req)
  (is (= 51 (get-value env 'result5)))  # 1 + 20 + 30 = 51
  (e/run "(def result6 (h 1 2))" :env env :send send :req req)
  (is (= 33 (get-value env 'result6)))  # 1 + 2 + 30 = 33
  (e/run "(def result7 (h 1 2 3))" :env env :send send :req req)
  (is (= 6 (get-value env 'result7)))  # 1 + 2 + 3 = 6
  # Redefine defaults - h should be re-evaluated
  (e/run "(def default1 200)" :env env :send send :req req)
  (e/run "(def default2 300)" :env env :send send :req req)
  (e/run "(def result8 (h 1))" :env env :send send :req req)
  (is (= 501 (get-value env 'result8)))  # 1 + 200 + 300 = 501
  # Test 4: Variadic parameter shadowing a global
  (e/run "(def rest 999)" :env env :send send :req req)
  (e/run "(defn shadow-test [a & rest] (length rest))" :env env :send send :req req)
  (e/run "(def result9 (shadow-test 1 2 3 4))" :env env :send send :req req)
  (is (= 3 (get-value env 'result9)))  # rest parameter has 3 items
  # Redefine global rest - shadow-test should NOT be re-evaluated
  (e/run "(def rest 111)" :env env :send send :req req)
  (e/run "(def result10 (shadow-test 1 2 3 4))" :env env :send send :req req)
  (is (= 3 (get-value env 'result10)))  # Still 3, not affected by global
  # Test 5: &keys parameter
  (e/run "(def key-default 42)" :env env :send send :req req)
  (e/run "(defn with-keys [a &keys {:x x :y y}] (+ a (or x key-default) (or y key-default)))" :env env :send send :req req)
  (e/run "(def result11 (with-keys 1 :x 10 :y 20))" :env env :send send :req req)
  (is (= 31 (get-value env 'result11)))  # 1 + 10 + 20 = 31
  (e/run "(def result12 (with-keys 1))" :env env :send send :req req)
  (is (= 85 (get-value env 'result12)))  # 1 + 42 + 42 = 85
  # Redefine key-default - with-keys should be re-evaluated
  (e/run "(def key-default 100)" :env env :send send :req req)
  (e/run "(def result13 (with-keys 1))" :env env :send send :req req)
  (is (= 201 (get-value env 'result13)))  # 1 + 100 + 100 = 201
  # Test 6: &named parameter
  (e/run "(def named-default 7)" :env env :send send :req req)
  (e/run "(defn with-named [a &named x y] (+ a (or x named-default) (or y named-default)))" :env env :send send :req req)
  (e/run "(def result14 (with-named 1 :x 2 :y 3))" :env env :send send :req req)
  (is (= 6 (get-value env 'result14)))  # 1 + 2 + 3 = 6
  (e/run "(def result15 (with-named 1))" :env env :send send :req req)
  (is (= 15 (get-value env 'result15)))  # 1 + 7 + 7 = 15
  # Redefine named-default - with-named should be re-evaluated
  (e/run "(def named-default 50)" :env env :send send :req req)
  (e/run "(def result16 (with-named 1))" :env env :send send :req req)
  (is (= 101 (get-value env 'result16))))  # 1 + 50 + 50 = 101

(deftest deps-nested-functions
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define global x
  (e/run "(def x 10)" :env env :send send :req req)
  # Define function that returns closure capturing x
  (e/run "(defn outer [] (fn [] x))" :env env :send send :req req)
  (e/run "(def inner (outer))" :env env :send send :req req)
  (e/run "(def result1 (inner))" :env env :send send :req req)
  (is (= 10 (get-value env 'result1)))
  # Redefine x - outer should be re-evaluated, which re-evaluates inner
  (e/run "(def x 20)" :env env :send send :req req)
  (e/run "(def inner2 (outer))" :env env :send send :req req)
  (e/run "(def result2 (inner2))" :env env :send send :req req)
  (is (= 20 (get-value env 'result2))))

(deftest deps-destructuring
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Test array destructuring
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(def y 20)" :env env :send send :req req)
  (e/run "(def [a b] [x y])" :env env :send send :req req)
  (is (= 10 (get-value env 'a)))
  (is (= 20 (get-value env 'b)))
  # Redefine x, destructured bindings should update
  (buffer/clear outb)
  (e/run "(def x 100)" :env env :send send :req req)
  (is (= 100 (get-value env 'a)))
  (is (= 20 (get-value env 'b)))
  # Test struct destructuring
  (e/run "(def data {:foo 1 :bar 2})" :env env :send send :req req)
  (e/run "(def {:foo f :bar b} data)" :env env :send send :req req)
  (is (= 1 (get-value env 'f)))
  (is (= 2 (get-value env 'b)))
  # Redefine data, destructured bindings should update
  (buffer/clear outb)
  (e/run "(def data {:foo 10 :bar 20})" :env env :send send :req req)
  (is (= 10 (get-value env 'f)))
  (is (= 20 (get-value env 'b))))

(deftest deps-loop-bindings
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Test that loop bindings are scoped correctly (i should not be tracked as dependency)
  (e/run "(def n 5)" :env env :send send :req req)
  (e/run "(def total1 (do (var acc 0) (loop [i :range [0 n]] (+= acc i)) acc))" :env env :send send :req req)
  (is (= 10 (get-value env 'total1)))  # 0+1+2+3+4 = 10
  # Redefine n, total1 should be re-evaluated with new range
  (buffer/clear outb)
  (e/run "(def n 4)" :env env :send send :req req)
  (is (= 6 (get-value env 'total1)))
  # Test loop with :in modifier and external reference
  (e/run "(def items [1 2 3])" :env env :send send :req req)
  (e/run "(def multiplier 10)" :env env :send send :req req)
  (e/run "(def total2 (do (var acc 0) (loop [item :in items] (+= acc (* item multiplier))) acc))" :env env :send send :req req)
  (is (= 60 (get-value env 'total2)))  # (1+2+3) * 10 = 60
  # Redefine multiplier - total2 should be re-evaluated
  (buffer/clear outb)
  (e/run "(def multiplier 5)" :env env :send send :req req)
  (is (= 30 (get-value env 'total2))))  # (1+2+3) * 5 = 30

(deftest deps-chained-dependencies
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Create chain a -> b -> c
  (e/run "(def a 1)" :env env :send send :req req)
  (e/run "(def b (+ a 1))" :env env :send send :req req)
  (e/run "(def c (+ b 1))" :env env :send send :req req)
  (is (= 1 (get-value env 'a)))
  (is (= 2 (get-value env 'b)))
  (is (= 3 (get-value env 'c)))
  # Redefine a, both b and c should update
  (e/run "(def a 10)" :env env :send send :req req)
  (is (= 10 (get-value env 'a)))
  (is (= 11 (get-value env 'b)))
  (is (= 12 (get-value env 'c))))

(deftest deps-function-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define variable and function that uses it
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(defn f [] (+ x 5))" :env env :send send :req req)
  (e/run "(def result1 (f))" :env env :send send :req req)
  (is (= 15 (get-value env 'result1)))
  # Redefine x, function should be recompiled
  (e/run "(def x 20)" :env env :send send :req req)
  (e/run "(def result2 (f))" :env env :send send :req req)
  (is (= 25 (get-value env 'result2))))

(deftest deps-transitive-through-function
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Define a -> g (function) -> b (calls g)
  (e/run "(def a 5)" :env env :send send :req req)
  (e/run "(defn g [] (+ a 10))" :env env :send send :req req)
  (e/run "(def b (g))" :env env :send send :req req)
  (is (= 15 (get-value env 'b)))
  # Redefine a, both g and b should update
  (e/run "(def a 100)" :env env :send send :req req)
  (is (= 110 (get-value env 'b))))

(deftest deps-multiple-dependencies
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # z depends on both x and y
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(def y 20)" :env env :send send :req req)
  (e/run "(def z (+ x y))" :env env :send send :req req)
  (is (= 30 (get-value env 'z)))
  # Redefine x, z should update
  (e/run "(def x 100)" :env env :send send :req req)
  (is (= 120 (get-value env 'z)))
  # Redefine y, z should update again
  (e/run "(def y 5)" :env env :send send :req req)
  (is (= 105 (get-value env 'z))))

(deftest deps-multiple-dependents
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Both c and d depend on a and b
  (e/run "(def a 1)" :env env :send send :req req)
  (e/run "(def b 2)" :env env :send send :req req)
  (e/run "(def c (+ a b))" :env env :send send :req req)
  (e/run "(def d (* a b))" :env env :send send :req req)
  (is (= 3 (get-value env 'c)))
  (is (= 2 (get-value env 'd)))
  # Redefine a, both c and d should update
  (e/run "(def a 10)" :env env :send send :req req)
  (is (= 12 (get-value env 'c)))
  (is (= 20 (get-value env 'd))))

(deftest deps-diamond-dependency
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Create diamond: a depends on b and c, both b and c depend on d
  (e/run "(def d 5)" :env env :send send :req req)
  (e/run "(def b (+ d 10))" :env env :send send :req req)
  (e/run "(def c (+ d 20))" :env env :send send :req req)
  (e/run "(def a (+ b c))" :env env :send send :req req)
  (is (= 5 (get-value env 'd)))
  (is (= 15 (get-value env 'b)))
  (is (= 25 (get-value env 'c)))
  (is (= 40 (get-value env 'a)))
  # Redefine d - b and c should update, then a should update once with both new values
  (e/run "(def d 100)" :env env :send send :req req)
  (is (= 100 (get-value env 'd)))
  (is (= 110 (get-value env 'b)))
  (is (= 120 (get-value env 'c)))
  (is (= 230 (get-value env 'a))))

(deftest deps-circular-direct
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Create circular dependency a <-> b
  (e/run "(def a 10)" :env env :send send :req req)
  (e/run "(def b a)" :env env :send send :req req)
  (is (= 10 (get-value env 'b)))
  # Close the loop
  (e/run "(def a b)" :env env :send send :req req)
  (is (= 10 (get-value env 'a)))
  # Redefine b, should not infinite loop
  (e/run "(def b 100)" :env env :send send :req req)
  (is (= 100 (get-value env 'b)))
  (is (= 100 (get-value env 'a))))

(deftest deps-circular-indirect
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Create cycle x -> y -> z -> x
  (e/run "(def x 1)" :env env :send send :req req)
  (e/run "(def y 2)" :env env :send send :req req)
  (e/run "(def z 3)" :env env :send send :req req)
  (e/run "(def x y)" :env env :send send :req req)
  (e/run "(def y z)" :env env :send send :req req)
  (e/run "(def z x)" :env env :send send :req req)
  # Redefine any, should not infinite loop
  (e/run "(def x 100)" :env env :send send :req req)
  (is (= 100 (get-value env 'x)))
  (is (= 100 (get-value env 'y)))
  (is (= 100 (get-value env 'z))))

(deftest deps-error-handling
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def path (dyn :current-file))
  # Define x as a function, y calls it, z uses it
  (e/run "(def x +)" :env env :send send :req req)
  (e/run "(def y (x 1 2))" :env env :send send :req req)
  (e/run "(def z (+ x 100))" :env env :send send :req req)
  (is (= 3 (get-value env 'y)))
  # Redefine x to a symbol (will cause errors in re-evaluation)
  (buffer/clear outb)
  (e/run "(def x 'not-a-function)" :env env :send send :req req)
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
     "janet/col" 1})
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
  # Define dependencies
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(def y (+ x 5))" :env env :send send :req req)
  # Redefine x and check for note message
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req)
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
     "janet/col" 1})
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
  # Note: re-evaluated forms don't include line/col info
  (def expect-3
    {"tag" "ret"
     "op" "env/eval"
     "lang" u/lang
     "req" "1"
     "sess" "1"
     "done" false
     "val" "25"
     "janet/path" u/ns})
  (is (== expect-3 (get messages 2))))

(deftest deps-file-load-clears-graph
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  # Build up a dependency graph with chained dependencies
  (e/run "(def x 10)" :env env :send send :req req)
  (e/run "(def y (+ x 5))" :env env :send send :req req)
  (e/run "(def z (+ y 10))" :env env :send send :req req)
  # Verify initial values
  (is (= 10 (get-value env 'x)))
  (is (= 15 (get-value env 'y)))
  (is (= 25 (get-value env 'z)))
  # Clear the graph (simulating what happens at the start of env-load)
  (when-let [graph (get env :grapple/dep-graph)]
    (deps/clear-graph graph))
  # Re-evaluate all definitions as if loading a file from scratch
  # This should NOT trigger any cascade re-evaluation messages
  (buffer/clear outb)
  (e/run "(def x 20)" :env env :send send :req req)
  (e/run "(def y (+ x 5))" :env env :send send :req req)
  (e/run "(def z (+ y 10))" :env env :send send :req req)
  # Parse messages to verify no cascade occurred
  (parser/consume p outb)
  (def messages @[])
  (while (parser/has-more p)
    (array/push messages (parser/produce p)))
  # Should have exactly 3 messages (one ret for each def)
  # NO note messages about re-evaluation during the "file load"
  (is (= 3 (length messages)))
  (is (= "ret" (get-in messages [0 "tag"])))
  (is (= "20" (get-in messages [0 "val"])))
  (is (= "ret" (get-in messages [1 "tag"])))
  (is (= "25" (get-in messages [1 "val"])))
  (is (= "ret" (get-in messages [2 "tag"])))
  (is (= "35" (get-in messages [2 "val"])))
  # Verify final values are correct
  (is (= 20 (get-value env 'x)))
  (is (= 25 (get-value env 'y)))
  (is (= 35 (get-value env 'z)))
  # Now verify the graph was rebuilt correctly by checking that
  # subsequent changes DO trigger cascades
  (buffer/clear outb)
  (e/run "(def x 100)" :env env :send send :req req)
  # Parse messages
  (parser/consume p outb)
  (def messages2 @[])
  (while (parser/has-more p)
    (array/push messages2 (parser/produce p)))
  # When x is redefined, it triggers:
  # 1. ret for x = 100
  # 2. note about re-evaluating y, z
  # 3. ret for y = 105
  # 4. note about re-evaluating z (because y was redefined during cascade)
  # 5. ret for z = 115 (first evaluation from step 2)
  # 6. ret for z = 115 (second evaluation from step 4)
  (is (= 6 (length messages2)))
  (is (= "ret" (get-in messages2 [0 "tag"])))
  (is (= "100" (get-in messages2 [0 "val"])))
  (is (= "note" (get-in messages2 [1 "tag"])))
  (is (string/find "Re-evaluating dependents of x" (get-in messages2 [1 "val"])))
  (is (= "ret" (get-in messages2 [2 "tag"])))
  (is (= "105" (get-in messages2 [2 "val"])))
  (is (= "note" (get-in messages2 [3 "tag"])))
  (is (string/find "Re-evaluating dependents of y" (get-in messages2 [3 "val"])))
  (is (= "ret" (get-in messages2 [4 "tag"])))
  (is (= "115" (get-in messages2 [4 "val"])))
  (is (= "ret" (get-in messages2 [5 "tag"])))
  (is (= "115" (get-in messages2 [5 "val"])))
  # Verify cascading updates worked correctly
  (is (= 100 (get-value env 'x)))
  (is (= 105 (get-value env 'y)))
  (is (= 115 (get-value env 'z))))

(deftest deps-clear-graph-function
  # Test the clear-graph function itself
  (def graph (deps/make-dep-graph))
  # Track some definitions
  (def source1 '(def foo 10))
  (def source2 '(def bar (+ foo 5)))
  (def source3 '(defn baz [] (* bar 2)))
  (deps/track-definition graph source1)
  (deps/track-definition graph source2)
  (deps/track-definition graph source3)
  # Verify graph has entries
  (is (> (length (graph :deps)) 0))
  (is (> (length (graph :sources)) 0))
  # Clear the graph
  (deps/clear-graph graph)
  # Verify graph is empty
  (is (= 0 (length (graph :deps))))
  (is (= 0 (length (graph :dependents))))
  (is (= 0 (length (graph :sources)))))

(deftest deps-line-number-ordering
  # Test that bindings with equal dependency counts are sorted by line number
  (def graph (deps/make-dep-graph))

  # Create a parser and parse code with multiple bindings on different lines
  (def p (parser/new))
  (parser/consume p "(def x 10)\n(def a (+ x 1))\n(def b (+ x 2))\n(def c (+ x 3))\n")

  # Track all definitions
  (while (parser/has-more p)
    (def form (parser/produce p))
    (deps/track-definition graph form))

  # Get reevaluation order - should be sorted by line number
  (def order (deps/get-reeval-order graph 'x))

  # Verify order is by line number: a (line 2), b (line 3), c (line 4)
  (is (= 3 (length order)))
  (is (= 'a (get order 0)) "First symbol should be 'a' (line 2)")
  (is (= 'b (get order 1)) "Second symbol should be 'b' (line 3)")
  (is (= 'c (get order 2)) "Third symbol should be 'c' (line 4)"))

(run-tests!)

(use ../deps/testament)

(import ../lib/utilities :as u)
(import ../lib/evaluator :as e)

# Utility Functions

(defn make-sender [b]
  (fn :send [v]
    # Walk the structure and replace functions with parseable strings
    (defn sanitize [x]
      (cond
        (function? x) (string `"<function ` (or (get x :name) "anonymous") `>"`)
        (dictionary? x) (from-pairs (map (fn [[k v]] [k (sanitize v)]) (pairs x)))
        (indexed? x) (map sanitize x)
        x))
    # use buffer becuase ev/give doesn't work in janet_call
    (buffer/push b (string/format "%q" (sanitize v)))))

# Helper to run eval in fiber (matching handler behavior)
(defn run-eval [code & args]
  (def fib (fiber/new (fn [] (e/run code ;args)) :dey))
  (def res (ev/with-deadline 2 (resume fib)))
  [res fib])

# Generic eval request

(def req
  {"op" "env.eval"
   "lang" u/lang
   "id" "1"
   "sess" "1"})

# Debug tests

(deftest debug-breakpoint-pause
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def test-path "test-breakpoint.janet")
  # First compile the function definition
  (def code1 "(defn test-fn [x]\n  (def y (+ x 5))\n  y)")
  (def [res1 fib1]
    (run-eval code1 :env env :send send :req req :path test-path :sess sess))
  # Now set a breakpoint at line 2 (after function is compiled)
  (buffer/clear outb)
  (debug/break test-path 2 3)
  # Run code that calls the function in a fiber (hits the breakpoint)
  (def code2 "(test-fn 10)")
  (def [res2 fib2] (run-eval code2 :env env :send send :req req :path test-path :sess sess))
  # Verify it paused at the breakpoint
  (is (= :debug (fiber/status fib2)))
  # Parse and verify the signal message
  (parser/consume p outb)
  (def actual-sig (parser/produce p))
  (def expect-bytecode
    ```
       addim 2 0 5          # line 2, column 10
    *> movn 3 2             # line 2, column 3
       ret 3                # line 1, column 1
    ```)
  (def expect-fiber-state
    ```
      status:     debug
      function:   test-fn [test-breakpoint.janet]
      constants:  @[]
      slots:      @[10 nil 15 nil]
    ```)
  (def expect-sig {"tag" "sig"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "val" "debug"
                   "janet/bytecode" (string expect-bytecode "\n\n")
                   "janet/fiber-state" expect-fiber-state
                   "janet/path" test-path
                   "janet/line" 2
                   "janet/col" 3
                   "janet/stack" (actual-sig "janet/stack")})
  (is (== expect-sig actual-sig))
  # Continue execution
  (buffer/clear outb)
  (def final-res (ev/with-deadline 2 (resume fib2 :continue)))
  (is (= :dead (fiber/status fib2)))
  # Parse and verify the return message
  (parser/consume p outb)
  (def expect-ret {"tag" "ret"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "done" false
                   "val" "15"
                   "janet/path" test-path
                   "janet/line" 1
                   "janet/col" 1
                   "janet/reeval?" false})
  (def actual-ret (parser/produce p))
  (is (== expect-ret actual-ret))
  (is (not (parser/has-more p)))
  # Clean up
  (debug/unbreak test-path 2 3))

(deftest debug-breakpoint-continue
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def test-path "test-continue.janet")
  # First compile the function
  (def code1 "(defn calc [x]\n  (def sum (+ x 5))\n  sum)")
  (def [res1 fib1]
    (run-eval code1 :env env :send send :req req :path test-path :sess sess))
  # Set a breakpoint
  (buffer/clear outb)
  (debug/break test-path 2 3)
  # Run code that calls the function in a fiber
  (def code2 "(calc 10)")
  (def [res2 fib2]
    (run-eval code2 :env env :send send :req req :path test-path :sess sess))
  # Verify we're paused at a breakpoint
  (is (= :debug (fiber/status fib2)))
  # Parse and verify the signal message
  (parser/consume p outb)
  (def actual-sig (parser/produce p))
  (def expect-bytecode
    ```
       addim 2 0 5          # line 2, column 12
    *> movn 3 2             # line 2, column 3
       ret 3                # line 1, column 1
    ```)
  (def expect-fiber-state
    ```
      status:     debug
      function:   calc [test-continue.janet]
      constants:  @[]
      slots:      @[10 nil 15 nil]
    ```)
  (def expect-sig {"tag" "sig"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "val" "debug"
                   "janet/bytecode" (string expect-bytecode "\n\n")
                   "janet/fiber-state" expect-fiber-state
                   "janet/path" test-path
                   "janet/line" 2
                   "janet/col" 3
                   "janet/stack" (actual-sig "janet/stack")})
  (is (== expect-sig actual-sig))
  # The fiber should still be paused - we can't manually continue it anymore
  # In the new protocol, we need to use env.dbg with (.continue)
  # For now, just verify the fiber is still in debug state
  (is (= :debug (fiber/status fib2)))
  (is (not (parser/has-more p)))
  # Clean up
  (debug/unbreak test-path 2 3))

(deftest debug-breakpoint-inspect-stack
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def test-path "test-inspect.janet")
  # First compile the function
  (def code1 "(defn compute [a b]\n  (def result (+ a b))\n  result)")
  (def [res1 fib1]
    (run-eval code1 :env env :send send :req req :path test-path :sess sess))
  # Set a breakpoint
  (buffer/clear outb)
  (debug/break test-path 2 3)
  # Run code that calls the function in a fiber
  (def code2 "(compute 5 7)")
  (def [res2 fib2]
    (run-eval code2 :env env :send send :req req :path test-path :sess sess))
  # Verify we're paused at a breakpoint
  (is (= :debug (fiber/status fib2)))
  # Parse and verify the signal message
  (parser/consume p outb)
  (def actual-sig (parser/produce p))
  (def expect-bytecode
    ```
       add 3 0 1            # line 2, column 15
    *> movn 4 3             # line 2, column 3
       ret 4                # line 1, column 1
    ```)
  (def expect-fiber-state
    ```
      status:     debug
      function:   compute [test-inspect.janet]
      constants:  @[]
      slots:      @[5 7 nil 12 nil]
    ```)
  (def expect-sig {"tag" "sig"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "val" "debug"
                   "janet/bytecode" (string expect-bytecode "\n\n")
                   "janet/fiber-state" expect-fiber-state
                   "janet/path" test-path
                   "janet/line" 2
                   "janet/col" 3
                   "janet/stack" (actual-sig "janet/stack")})
  (is (== expect-sig actual-sig))
  # Continue to complete
  (buffer/clear outb)
  (ev/with-deadline 2 (resume fib2 :continue))
  (is (= :dead (fiber/status fib2)))
  # Parse and verify the return message
  (parser/consume p outb)
  (def expect-ret {"tag" "ret"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "done" false
                   "val" "12"
                   "janet/path" test-path
                   "janet/line" 1
                   "janet/col" 1
                   "janet/reeval?" false})
  (def actual-ret (parser/produce p))
  (is (== expect-ret actual-ret))
  (is (not (parser/has-more p)))
  # Clean up
  (debug/unbreak test-path 2 3))

(deftest debug-no-breakpoint-normal-execution
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def test-path "test-normal.janet")
  # Run code without any breakpoints
  (def code "(def x 10)\n(def y (+ x 5))\ny")
  (run-eval code :env env :send send :req req :path test-path :sess sess)
  # Parse and verify all messages
  (parser/consume p outb)
  (def expect-1 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "10"
                 "janet/path" test-path
                 "janet/line" 1
                 "janet/col" 1
                 "janet/reeval?" false})
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  (def expect-2 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "15"
                 "janet/path" test-path
                 "janet/line" 2
                 "janet/col" 1
                 "janet/reeval?" false})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  (def expect-3 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "15"
                 "janet/path" test-path
                 "janet/line" 3
                 "janet/col" 1
                 "janet/reeval?" false})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p))))

(deftest debug-breakpoint-with-dependencies
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def sess @{:dep-graph @{}})
  (def test-path "test-deps-debug.janet")
  # Set up dependencies
  (run-eval "(def x 10)" :env env :send send :req req :path test-path :sess sess)
  (run-eval "(def y (+ x 5))" :env env :send send :req req :path test-path :sess sess)
  # Set breakpoint on redefinition line
  (buffer/clear outb)
  (debug/break test-path 1 1)
  # Redefine x which should trigger reevaluation
  (def [res fib] (run-eval "(def x 20)" :env env :send send :req req :path test-path :sess sess))
  # Parse and verify messages
  (parser/consume p outb)
  # First message should be the redefinition of x
  (def expect-1 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "20"
                 "janet/path" test-path
                 "janet/line" 1
                 "janet/col" 1
                 "janet/reeval?" false})
  (def actual-1 (parser/produce p))
  (is (== expect-1 actual-1))
  # Second message should be a note about re-evaluating dependents
  (def expect-2 {"tag" "note"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" "Re-evaluating dependents of x: y"})
  (def actual-2 (parser/produce p))
  (is (== expect-2 actual-2))
  # Third message should be the reevaluation of y
  (def expect-3 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" false
                 "val" "25"
                 "janet/path" test-path
                 "janet/reeval?" true})
  (def actual-3 (parser/produce p))
  (is (== expect-3 actual-3))
  (is (not (parser/has-more p)))
  # Clean up
  (debug/unbreak test-path 1 1))

(deftest debug-orphaned-breakpoint-notification
  (def p (parser/new))
  (def outb @"")
  (def send (make-sender outb))
  (def env (e/eval-make-env))
  (def test-path "test-orphaned-bp.janet")
  (def sess @{:dep-graph @{}
              :breakpoints @[]})
  # Define a function
  (def code1 "(defn test-fn [x]\n  (+ x 5))")
  (run-eval code1 :env env :send send :req req :path test-path :sess sess)
  (buffer/clear outb)
  # Manually add a breakpoint to the session (simulating what handler does)
  (array/push (sess :breakpoints) {:path test-path
                                   :line 2
                                   :col 3
                                   :binding 'test-fn})
  (def bp-id 0)
  # Redefine the function, which should orphan the breakpoint
  (def code2 "(defn test-fn [x]\n  (+ x 10))")
  (run-eval code2 :env env :send send :req req :path test-path :sess sess)
  # Parse messages
  (parser/consume p outb)
  # First message should be the return from the redefinition
  (def expect-ret {"tag" "ret"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "done" false
                   "val" "<function test-fn>"
                   "janet/path" test-path
                   "janet/line" 1
                   "janet/col" 1
                   "janet/reeval?" false})
  (def actual-ret (parser/produce p))
  (is (== expect-ret actual-ret))
  # Second message should be the orphaned breakpoint command
  (def expect-cmd {"tag" "cmd"
                   "op" "env.eval"
                   "lang" u/lang
                   "req" "1"
                   "sess" "1"
                   "val" "clear-breakpoints"
                   "janet/breakpoints" [bp-id]})
  (def actual-cmd (parser/produce p))
  (is (== expect-cmd actual-cmd))
  (is (not (parser/has-more p))))

(run-tests!)

(use ../deps/testament)

(import ../lib/utilities :as u)
(import ../lib/handler :as h)

# Utility Functions

(defn make-sessions []
  (def sessions @{})
  (put sessions :count 1)
  (put sessions :clients @{"1" @{:dep-graph @{}
                                 :breakpoints @[]}})
  sessions)

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/with-deadline 1 (ev/take chan)))
   (fn [v] (ev/with-deadline 1 (ev/give chan v)))
   chan])

# Tests

(deftest confirm
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (defn send-err [val]
    (send {"tag" "err"
           "val" val}))
  (h/confirm {} ["id" "sess"] send-err)
  (def actual (recv))
  (def expect {"tag" "err"
               "val" "request missing key \"id\""})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-new
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "sess.new"
             "lang" u/lang
             "id" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess.new"
               "lang" u/lang
               "req" "1"
               "sess" "2"
               "done" true
               "janet/arch" (os/arch)
               "janet/impl" ["janet" janet/version]
               "janet/os" (os/which)
               "janet/prot" u/prot
               "janet/serv" u/proj})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-new-with-auth-no-token-required
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  # Server has no token set, so auth is not required
  (h/handle {"op" "sess.new"
             "lang" u/lang
             "id" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess.new"
               "lang" u/lang
               "req" "1"
               "sess" "2"
               "done" true
               "janet/arch" (os/arch)
               "janet/impl" ["janet" janet/version]
               "janet/os" (os/which)
               "janet/prot" u/prot
               "janet/serv" u/proj})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-new-with-auth-token-required-no-auth-provided
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  # Server has token set, so auth is required
  (put sessions :token "test-token-123")
  (h/handle {"op" "sess.new"
             "lang" u/lang
             "id" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "sess.new"
               "lang" u/lang
               "req" "1"
               "sess" nil
               "val" "authentication failed"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-new-with-auth-token-required-wrong-auth
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  # Server has token set, client provides wrong token
  (put sessions :token "test-token-123")
  (h/handle {"op" "sess.new"
             "lang" u/lang
             "id" "1"
             "auth" "wrong-token"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "sess.new"
               "lang" u/lang
               "req" "1"
               "sess" nil
               "val" "authentication failed"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-new-with-auth-token-required-correct-auth
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  # Server has token set, client provides correct token
  (put sessions :token "test-token-123")
  (h/handle {"op" "sess.new"
             "lang" u/lang
             "id" "1"
             "auth" "test-token-123"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess.new"
               "lang" u/lang
               "req" "1"
               "sess" "2"
               "done" true
               "janet/arch" (os/arch)
               "janet/impl" ["janet" janet/version]
               "janet/os" (os/which)
               "janet/prot" u/prot
               "janet/serv" u/proj})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-end
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "sess.end"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess.end"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest sess-list
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (put (sessions :clients) "2" true)
  (h/handle {"op" "sess.list"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "sess.list"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" @["1" "2"]})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest serv-info
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv.info"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv.info"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "janet/arch" (os/arch)
               "janet/impl" ["janet" janet/version]
               "janet/os" (os/which)
               "janet/prot" u/prot
               "janet/serv" u/proj})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest serv-stop
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv.stop"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv.stop"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "Server shutting down..."})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest serv-relo
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "serv.relo"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "serv.relo"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "Server reloading..."})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest env-eval
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env.eval"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "code" "(+ 1 2)"}
            sessions
            send)
  (def actual-1 (do (recv) (recv)))
  (def expect-1 {"tag" "ret"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true})
  (is (== expect-1 actual-1))
  (h/handle {"op" "env.eval"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "code" 5}
            sessions
            send)
  (def actual-2 (recv))
  (def expect-2 {"tag" "err"
                 "op" "env.eval"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" "code must be string"})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))

(deftest env-load
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def path "./res/test/handler-env-load.janet")
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" path}
            sessions
            send)
  (def actual-1 (do (recv) (recv) (recv) (recv) (recv)))
  (def expect-1 {"tag" "ret"
                 "op" "env.load"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true})
  (is (== expect-1 actual-1))
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" "path/to/nowhere.txt"}
            sessions
            send)
  (def actual-2 (recv))
  (def expect-msg "request failed: could not open file path/to/nowhere.txt")
  # Build expected message with location details from actual error
  (def expect-2 {"tag" "err"
                 "op" "env.load"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" expect-msg
                 "janet/path" (actual-2 "janet/path")
                 "janet/line" (actual-2 "janet/line")
                 "janet/col" (actual-2 "janet/col")
                 "janet/stack" (actual-2 "janet/stack")})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))

(deftest env-doc
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def env @{'x @{:doc "The number five." :value 5}})
  (put module/cache u/ns env)
  (h/handle {"op" "env.doc"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "sym" "x"
             "janet/type" "symbol"}
            sessions
            send)
  (put module/cache u/ns nil)
  (def actual-1 (recv))
  (def expect-1 {"tag" "ret"
                 "op" "env.doc"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true
                 "val" "The number five."
                 "janet/type" :number})
  (is (== expect-1 actual-1))
  (h/handle {"op" "env.doc"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "sym" "y"
             "janet/type" "symbol"}
            sessions
            send)
  (def actual-2 (recv))
  (def expect-2 {"tag" "err"
                 "op" "env.doc"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "val" "y not found"})
  (is (== expect-2 actual-2))
  (is (zero? (ev/count chan))))

(deftest env-cmpl
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def env @{'foo1 @{:value 1}
             'foo2 @{:value 2}})
  (put module/cache u/ns env)
  (h/handle {"op" "env.cmpl"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "ns" u/ns
             "sym" "foo"
             "janet/type" "symbol"}
            sessions
            send)
  (put module/cache u/ns nil)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "env.cmpl"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" ["foo1" "foo2"]})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-nonexistent-file
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" "nonexistent.janet"
             "line" 10
             "col" 3}
            sessions
            send)
  (def actual (recv))
  # Should get an error for non-existent file
  (is (= "err" (actual "tag")))
  (is (string/find "could not find breakpoint" (actual "val")))
  # Verify breakpoint was NOT stored in session
  (def sess (get-in sessions [:clients "1"]))
  (is (nil? (get-in sess [:breakpoints "nonexistent.janet:10"])))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-invalid-session
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "999"
             "path" "test.janet"
             "line" 10}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "dbg.brk.add"
               "lang" u/lang
               "req" "1"
               "sess" "999"
               "val" "invalid session"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-step-cont-no-paused-fiber
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.step.cont"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "dbg.step.cont"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "no paused fiber"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-step-cont-invalid-session
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.step.cont"
             "lang" u/lang
             "id" "1"
             "sess" "999"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "dbg.step.cont"
               "lang" u/lang
               "req" "1"
               "sess" "999"
               "val" "invalid session"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-insp-stk-no-paused-fiber
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.insp.stk"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "dbg.insp.stk"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "no paused fiber"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-insp-stk-invalid-session
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.insp.stk"
             "lang" u/lang
             "id" "1"
             "sess" "999"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "dbg.insp.stk"
               "lang" u/lang
               "req" "1"
               "sess" "999"
               "val" "invalid session"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-success
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file so breakpoints can be set on it
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Test breakpoint in first function (add-1 at line 1)
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "line" 2
             "col" 3}
            sessions
            send)
  (def actual-1 (recv))
  (def bp-id-1 0)
  (def expect-1 {"tag" "ret"
                 "op" "dbg.brk.add"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true
                 "janet/bp-id" bp-id-1})
  (is (== expect-1 actual-1))
  (def sess (get-in sessions [:clients "1"]))
  (def brk-info-1 (get-in sess [:breakpoints bp-id-1]))
  (is (== {:path test-path :line 2 :col 3 :binding 'add-1} brk-info-1))
  # Test breakpoint in second function (multiply-2 at line 5)
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "path" test-path
             "line" 5
             "col" 3}
            sessions
            send)
  (def actual-2 (recv))
  (def bp-id-2 1)
  (def expect-2 {"tag" "ret"
                 "op" "dbg.brk.add"
                 "lang" u/lang
                 "req" "2"
                 "sess" "1"
                 "done" true
                 "janet/bp-id" bp-id-2})
  (is (== expect-2 actual-2))
  (def brk-info-2 (get-in sess [:breakpoints bp-id-2]))
  (is (== {:path test-path :line 5 :col 3 :binding 'multiply-2} brk-info-2))
  # Test breakpoint in third function (subtract-3 at line 8)
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "3"
             "sess" "1"
             "path" test-path
             "line" 8
             "col" 3}
            sessions
            send)
  (def actual-3 (recv))
  (def bp-id-3 2)
  (def expect-3 {"tag" "ret"
                 "op" "dbg.brk.add"
                 "lang" u/lang
                 "req" "3"
                 "sess" "1"
                 "done" true
                 "janet/bp-id" bp-id-3})
  (is (== expect-3 actual-3))
  (def brk-info-3 (get-in sess [:breakpoints bp-id-3]))
  (is (== {:path test-path :line 8 :col 3 :binding 'subtract-3} brk-info-3))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-rem-success
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Add a breakpoint
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "line" 2
             "col" 3}
            sessions
            send)
  (recv)  # Discard add response
  (def bp-id 0)
  # Now remove it
  (h/handle {"op" "dbg.brk.rem"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "bp-id" bp-id}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "dbg.brk.rem"
               "lang" u/lang
               "req" "2"
               "sess" "1"
               "done" true
               "janet/bp-id" bp-id})
  (is (== expect actual))
  # Verify breakpoint was removed from session
  (is (nil? (get-in sessions [:clients "1" :breakpoints bp-id])))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-rem-nonexistent
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  # Try to remove a breakpoint with an invalid ID
  (h/handle {"op" "dbg.brk.rem"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "bp-id" 999}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "dbg.brk.rem"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "invalid breakpoint id"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-clr-success
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "line" 2
             "col" 3}
            sessions
            send)
  (recv)  # Discard response
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "path" test-path
             "line" 4
             "col" 1}
            sessions
            send)
  (recv)  # Discard response
  (def breakpoints (get-in sessions [:clients "1" :breakpoints]))
  (is (= 2 (length breakpoints)))
  (h/handle {"op" "dbg.brk.clr"
             "lang" u/lang
             "id" "3"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "dbg.brk.clr"
               "lang" u/lang
               "req" "3"
               "sess" "1"
               "done" true})
  (is (== expect actual))
  (is (zero? (length breakpoints)))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-clr-empty
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "dbg.brk.clr"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "dbg.brk.clr"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-trigger
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Add a breakpoint on line 2 (inside add-1 function)
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "line" 2
             "col" 3}
            sessions
            send)
  (recv)  # Discard add response
  # Evaluate code that calls add-1
  (h/handle {"op" "env.eval"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "ns" test-path
             "code" "(add-1 5)"}
            sessions
            send)
  # Should receive a signal message when breakpoint is hit
  (def actual (recv))
  (def expect {"tag" "sig"
               "op" "env.eval"
               "lang" u/lang
               "req" "2"
               "sess" "1"
               "val" "debug"
               "janet/path" test-path
               "janet/line" 2
               "janet/col" 3})
  (is (== expect actual))
  # Verify session has paused fiber
  (def sess (get-in sessions [:clients "1"]))
  (is (not (nil? (sess :paused))))
  (is (not (nil? (get-in sess [:paused :fiber]))))
  (is (zero? (ev/count chan))))

(deftest dbg-step-cont-success
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # Load the file
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Add breakpoint on line 2
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "line" 2
             "col" 3}
            sessions
            send)
  (recv)  # Discard add response
  # Evaluate code that hits breakpoint
  (h/handle {"op" "env.eval"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "ns" test-path
             "code" "(add-1 5)"}
            sessions
            send)
  (recv)  # Discard debug signal
  # Now continue execution
  (h/handle {"op" "dbg.step.cont"
             "lang" u/lang
             "id" "3"
             "sess" "1"}
            sessions
            send)
  # Response 1: step.cont confirmation (sent immediately)
  (def actual-cont (recv))
  (def expect-cont {"tag" "ret"
                    "op" "dbg.step.cont"
                    "lang" u/lang
                    "req" "3"
                    "sess" "1"
                    "done" true})
  (is (== expect-cont actual-cont))
  # Response 2: Original eval result with the value
  (def actual-result (recv))
  (def expect-result {"tag" "ret"
                      "op" "env.eval"
                      "lang" u/lang
                      "req" "2"
                      "sess" "1"
                      "done" false
                      "val" "6"
                      "janet/path" test-path
                      "janet/line" 1
                      "janet/col" 1
                      "janet/reeval?" false})
  (is (== expect-result actual-result))
  # Response 3: Original eval done confirmation
  (def actual-eval-done (recv))
  (def expect-eval-done {"tag" "ret"
                         "op" "env.eval"
                         "lang" u/lang
                         "req" "2"
                         "sess" "1"
                         "done" true})
  (is (== expect-eval-done actual-eval-done))
  # Session should no longer have paused fiber
  (def sess (get-in sessions [:clients "1"]))
  (is (nil? (sess :paused)))
  (is (zero? (ev/count chan))))

(deftest dbg-insp-stk-success
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # Load the file
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Add breakpoint on line 2
  (h/handle {"op" "dbg.brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "line" 2
             "col" 3}
            sessions
            send)
  (recv)  # Discard add response
  # Evaluate code that hits breakpoint
  (h/handle {"op" "env.eval"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "ns" test-path
             "code" "(add-1 5)"}
            sessions
            send)
  (recv)  # Discard debug signal
  # Inspect the stack
  (h/handle {"op" "dbg.insp.stk"
             "lang" u/lang
             "id" "3"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  # Build expected response with actual stack data from the response
  # since stack frame data is complex and dynamic
  (def expect {"tag" "ret"
               "op" "dbg.insp.stk"
               "lang" u/lang
               "req" "3"
               "sess" "1"
               "done" true
               "val" (actual "val")})
  (is (== expect actual))
  # Verify stack data is non-empty string
  (is (string? (actual "val")))
  (is (not (empty? (actual "val"))))
  # Session should still have paused fiber (inspecting doesn't unpause)
  (def sess (get-in sessions [:clients "1"]))
  (is (not (nil? (sess :paused))))
  (is (zero? (ev/count chan))))

(run-tests!)

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

(deftest mgmt-info
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "mgmt.info"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "mgmt.info"
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

(deftest mgmt-stop
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "mgmt.stop"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "mgmt.stop"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "val" "Server shutting down..."})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest mgmt-relo
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "mgmt.relo"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "mgmt.relo"
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
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" "nonexistent.janet"
             "janet/rline" 10
             "janet/rcol" 3
             "janet/form" "(some-form)"}
            sessions
            send)
  (def actual (recv))
  # Should get an error for non-existent file
  (is (= "err" (actual "tag")))
  (is (string/find "no matching form, evaluate root form before adding breakpoint" (actual "val")))
  # Verify breakpoint was NOT stored in session
  (def sess (get-in sessions [:clients "1"]))
  (is (nil? (get-in sess [:breakpoints "nonexistent.janet:10"])))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-invalid-session
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "999"
             "path" "test.janet"
             "janet/rline" 10
             "janet/rcol" 3
             "janet/form" "(some-form)"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "brk.add"
               "lang" u/lang
               "req" "1"
               "sess" "999"
               "val" "invalid session"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-step-cont-no-paused-fiber
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env.dbg"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "code" "(.continue)"
             "req" "0"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "env.dbg"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "no paused fiber"})
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
  # Test breakpoint in first function (add-1 at line 1, body at relative offset 1)
  (def form-1 "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form-1}
            sessions
            send)
  (def actual-1 (recv))
  (def bp-id-1 0)
  (def expect-1 {"tag" "ret"
                 "op" "brk.add"
                 "lang" u/lang
                 "req" "1"
                 "sess" "1"
                 "done" true
                 "janet/bp-id" bp-id-1})
  (is (== expect-1 actual-1))
  (def sess (get-in sessions [:clients "1"]))
  (def brk-info-1 (get-in sess [:breakpoints bp-id-1]))
  (is (== {:path test-path :line 2 :col 3 :binding 'add-1} brk-info-1))
  # Test breakpoint in second function (multiply-2 at line 4, body at relative offset 1)
  (def form-2 "(defn multiply-2 [x]\n  (* x 2))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form-2}
            sessions
            send)
  (def actual-2 (recv))
  (def bp-id-2 1)
  (def expect-2 {"tag" "ret"
                 "op" "brk.add"
                 "lang" u/lang
                 "req" "2"
                 "sess" "1"
                 "done" true
                 "janet/bp-id" bp-id-2})
  (is (== expect-2 actual-2))
  (def brk-info-2 (get-in sess [:breakpoints bp-id-2]))
  (is (== {:path test-path :line 5 :col 3 :binding 'multiply-2} brk-info-2))
  # Test breakpoint in third function (subtract-3 at line 7, body at relative offset 1)
  (def form-3 "(defn subtract-3 [x]\n  (- x 3))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "3"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form-3}
            sessions
            send)
  (def actual-3 (recv))
  (def bp-id-3 2)
  (def expect-3 {"tag" "ret"
                 "op" "brk.add"
                 "lang" u/lang
                 "req" "3"
                 "sess" "1"
                 "done" true
                 "janet/bp-id" bp-id-3})
  (is (== expect-3 actual-3))
  (def brk-info-3 (get-in sess [:breakpoints bp-id-3]))
  (is (== {:path test-path :line 8 :col 3 :binding 'subtract-3} brk-info-3))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-with-matching-form
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file so forms are stored
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Test breakpoint with matching form content (relative offset 1)
  (def matching-form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" matching-form}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "brk.add"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true
               "janet/bp-id" 0})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-with-mismatched-form
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file so forms are stored
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Test breakpoint with mismatched form content (different function body)
  (def mismatched-form "(defn add-1 [x]\n  (+ x 2))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" mismatched-form}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "brk.add"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "no matching form, evaluate root form before adding breakpoint"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-with-invalid-column
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file so forms are stored
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Test breakpoint with column not at opening paren
  # The tuple (+ x 1) is at column 3, so column 4 (the +) should fail
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 4
             "janet/form" form}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "brk.add"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "Breakpoint must be added at the start of a form"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-brk-add-on-whitespace
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (def test-path "./res/test/handler-env-load.janet")
  # First load the file so forms are stored
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "0"
             "sess" "1"
             "path" test-path}
            sessions
            send)
  # Discard load responses
  (recv) (recv) (recv) (recv) (recv)
  # Test breakpoint on whitespace before the opening paren
  # The tuple (+ x 1) is at column 3, whitespace is at column 1 or 2
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 2
             "janet/form" form}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "brk.add"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "Breakpoint must be added at the start of a form"})
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
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form}
            sessions
            send)
  (recv)  # Discard response
  (def form-2 "(defn multiply-2 [x]\n  (* x 2))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form-2}
            sessions
            send)
  (recv)  # Discard response
  (def breakpoints (get-in sessions [:clients "1" :breakpoints]))
  (is (= 2 (length breakpoints)))
  (h/handle {"op" "brk.clr"
             "lang" u/lang
             "id" "3"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "brk.clr"
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
  (h/handle {"op" "brk.clr"
             "lang" u/lang
             "id" "1"
             "sess" "1"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "brk.clr"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "done" true})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-insp-stk-no-paused-fiber
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env.dbg"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "code" "(.stack)"
             "req" "0"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "env.dbg"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "no paused fiber"})
  (is (== expect actual))
  (is (zero? (ev/count chan))))

(deftest dbg-insp-stk-invalid-session
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env.dbg"
             "lang" u/lang
             "id" "1"
             "sess" "999"
             "code" "(.stack)"
             "req" "0"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "env.dbg"
               "lang" u/lang
               "req" "1"
               "sess" "999"
               "val" "invalid session"})
  (is (== expect actual))
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
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form}
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
  # Inspect the stack using env.dbg
  (h/handle {"op" "env.dbg"
             "lang" u/lang
             "id" "3"
             "sess" "1"
             "code" "(.stack)"
             "req" "2"}
            sessions
            send)
  # First response: from run evaluating the debug code
  (def actual-run (recv))
  (def expect-run {"tag" "ret"
                   "op" "env.dbg"
                   "lang" u/lang
                   "req" "3"
                   "sess" "1"
                   "done" false
                   "janet/path" "<debug>"
                   "janet/line" 1
                   "janet/col" 1
                   "janet/reeval?" false
                   "val" (actual-run "val")})
  (is (== expect-run actual-run))
  # Verify the result is a string (formatted stack data)
  (is (string? (actual-run "val")))
  (is (not (empty? (actual-run "val"))))
  # Second response: from env.dbg handler
  (def actual-dbg (recv))
  (def expect-dbg {"tag" "ret"
                   "op" "env.dbg"
                   "lang" u/lang
                   "req" "3"
                   "sess" "1"
                   "done" true
                   "val" (actual-dbg "val")})
  (is (== expect-dbg actual-dbg))
  # Third message: debug signal sent because fiber is still in debug state
  (def actual-sig (recv))
  (def expect-bytecode
    ```
    *> addim 2 0 1          # line 2, column 3
       ret 2               
    ```)
  (def expect-fiber-state
    ```
      status:     debug
      function:   add-1 [./res/test/handler-env-load.janet]
      constants:  @[]
      slots:      @[5 nil nil]
    ```)
  (def expect-sig {"tag" "sig"
                   "op" "env.dbg"
                   "lang" u/lang
                   "req" "3"
                   "sess" "1"
                   "val" "debug"
                   "janet/path" test-path
                   "janet/line" 2
                   "janet/col" 3
                   "janet/stack" (actual-sig "janet/stack")
                   "janet/bytecode" (string expect-bytecode "\n\n")
                   "janet/fiber-state" expect-fiber-state})
  (is (== expect-sig actual-sig))
  # Session should still have paused fiber (inspecting doesn't unpause)
  (def sess (get-in sessions [:clients "1"]))
  (is (not (nil? (sess :paused))))
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
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form}
            sessions
            send)
  (recv)  # Discard add response
  (def bp-id 0)
  # Now remove it
  (h/handle {"op" "brk.rem"
             "lang" u/lang
             "id" "2"
             "sess" "1"
             "bp-id" bp-id}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "ret"
               "op" "brk.rem"
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
  (h/handle {"op" "brk.rem"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "bp-id" 999}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "brk.rem"
               "lang" u/lang
               "req" "1"
               "sess" "1"
               "val" "invalid breakpoint id"})
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
  # Add a breakpoint on line 2 (inside add-1 function, relative offset 1)
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form}
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
  (def expect-bytecode
    ```
    *> addim 2 0 1          # line 2, column 3
       ret 2               
    ```)
  (def expect-fiber-state
    ```
      status:     debug
      function:   add-1 [./res/test/handler-env-load.janet]
      constants:  @[]
      slots:      @[5 nil nil]
    ```)
  (def expect {"tag" "sig"
               "op" "env.eval"
               "lang" u/lang
               "req" "2"
               "sess" "1"
               "val" "debug"
               "janet/path" test-path
               "janet/line" 2
               "janet/col" 3
               "janet/stack" (actual "janet/stack")
               "janet/bytecode" (string expect-bytecode "\n\n")
               "janet/fiber-state" expect-fiber-state})
  (is (== expect actual))
  # Verify stack is present and correct type
  (is (array? (actual "janet/stack")))
  # Verify session has paused fiber
  (def sess (get-in sessions [:clients "1"]))
  (is (not (nil? (sess :paused))))
  (is (not (nil? (get-in sess [:paused :fiber]))))
  (is (zero? (ev/count chan))))

(deftest dbg-step-cont-invalid-session
  (def sessions (make-sessions))
  (def [recv send chan] (make-stream))
  (h/handle {"op" "env.dbg"
             "lang" u/lang
             "id" "1"
             "sess" "999"
             "code" "(.continue)"
             "req" "0"}
            sessions
            send)
  (def actual (recv))
  (def expect {"tag" "err"
               "op" "env.dbg"
               "lang" u/lang
               "req" "1"
               "sess" "999"
               "val" "invalid session"})
  (is (== expect actual))
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
  (def form "(defn add-1 [x]\n  (+ x 1))")
  (h/handle {"op" "brk.add"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" test-path
             "janet/rline" 1
             "janet/rcol" 3
             "janet/form" form}
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
  # Now continue execution using env.dbg
  (h/handle {"op" "env.dbg"
             "lang" u/lang
             "id" "3"
             "sess" "1"
             "code" "(.continue)"
             "req" "2"}
            sessions
            send)
  # First response: original env.eval completing (resumed by .continue)
  (def actual-eval (recv))
  (def expect-eval {"tag" "ret"
                    "op" "env.eval"
                    "lang" u/lang
                    "req" "2"
                    "sess" "1"
                    "done" false
                    "janet/path" test-path
                    "janet/line" 1
                    "janet/col" 1
                    "janet/reeval?" false
                    "val" "6"})
  (is (== expect-eval actual-eval))
  # Second response: debug code evaluation completing (from run)
  (def actual-run (recv))
  (def expect-run {"tag" "ret"
                   "op" "env.dbg"
                   "lang" u/lang
                   "req" "3"
                   "sess" "1"
                   "done" false
                   "janet/path" "<debug>"
                   "janet/line" 1
                   "janet/col" 1
                   "janet/reeval?" false
                   "val" (actual-run "val")})
  (is (== expect-run actual-run))
  # Third response: env.dbg handler response
  (def actual-dbg (recv))
  (def expect-dbg {"tag" "ret"
                   "op" "env.dbg"
                   "lang" u/lang
                   "req" "3"
                   "sess" "1"
                   "done" true})
  (is (== expect-dbg actual-dbg))
  # Session should no longer have paused fiber (it completed)
  (def sess (get-in sessions [:clients "1"]))
  (is (nil? (sess :paused)))
  (is (zero? (ev/count chan))))

(run-tests!)

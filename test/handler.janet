(import /deps/testament :prefix "" :exit true)
(import ../lib/utilities :as u)
(import ../lib/handler :as h)

# Fixtures

(def sessions @{})

(defn setup []
  (table/clear sessions)
  (put sessions :count 1)
  (put sessions :clients @{"1" @{:dep-graph @{}}}))

# Utility Functions

(defn make-stream []
  (def chan (ev/chan 5))
  [(fn [] (ev/with-deadline 1 (ev/take chan)))
   (fn [v] (ev/with-deadline 1 (ev/give chan v)))
   chan])

# Tests

(deftest confirm
  (setup)
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
  (setup)
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

(deftest sess-end
  (setup)
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
  (setup)
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
  (setup)
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
  (setup)
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
  (setup)
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
  (setup)
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
  (setup)
  (def [recv send chan] (make-stream))
  (def path "./res/test/handler-env-load.janet")
  (h/handle {"op" "env.load"
             "lang" u/lang
             "id" "1"
             "sess" "1"
             "path" path}
            sessions
            send)
  (def actual-1 (do (recv) (recv) (recv)))
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
  (setup)
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
  (setup)
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

(run-tests!)

(local {: describe : it : before_each} (require :plenary.busted))
(local assert (require :luassert.assert))

;; Mock dependencies before requiring handler
(var log-calls [])
(var state-data {:conn {} :breakpoints {}})
(var editor-calls [])
(var ui-calls [])

(local mock-log
  {:append (fn [sec lines]
             (table.insert log-calls {:sec sec :lines lines}))})

(local mock-state
  {:get (fn [key]
          (if key
            (. state-data key)
            state-data))})

(local mock-editor
  {:go-to (fn [path line col]
            (table.insert editor-calls {:path path :line line :col col}))})

(local mock-str
  {:split (fn [text sep]
            (let [result []]
              (each [part (string.gmatch text (.. "[^" sep "]+"))]
                (table.insert result part))
              result))})

(local mock-ui
  {:add-breakpoint-sign (fn [bufnr file-path line bp-id]
                          (table.insert ui-calls {:op "add" :bufnr bufnr :file-path file-path :line line :bp-id bp-id}))
   :get-sign-current-line (fn [sign-id]
                            ;; Return line 10 for test sign-id
                            (if (= sign-id 123) 10 nil))
   :remove-breakpoint-sign (fn [sign-id]
                             (table.insert ui-calls {:op "remove" :sign-id sign-id}))
   :clear-breakpoint-signs (fn []
                             (table.insert ui-calls {:op "clear"}))
   :show-debug-indicators (fn [bufnr file-path line]
                            (table.insert ui-calls {:op "show-debug" :bufnr bufnr :file-path file-path :line line}))
   :hide-debug-indicators (fn []
                            (table.insert ui-calls {:op "hide-debug"}))})

;; Use real nfnl instead of mocking it
(local n (require :nfnl.core))

;; Install mocks
(tset package.loaded :grapple.client.log mock-log)
(tset package.loaded :grapple.client.state mock-state)
(tset package.loaded :grapple.client.ui mock-ui)
(tset package.loaded :conjure.editor mock-editor)
(tset package.loaded :conjure.nfnl.string mock-str)
(tset package.loaded :conjure.nfnl.core n)

;; Now require handler
(local handler (require :grapple.client.handler))

(describe "handle-message"
  (fn []
    (before_each
      (fn []
        (set log-calls [])
        (set state-data {:conn {}
                         :breakpoints {123 {:bufnr 1
                                            :file-path "./test.janet"
                                            :line 10
                                            :bp-id 0}}})
        (set editor-calls [])
        (set ui-calls [])))

    (it "handles sess.new messages"
      (fn []
        (let [msg {:op "sess.new"
                   :sess "test-session-123"
                   :janet/impl ["janet" "1.37.0"]
                   :janet/serv ["grapple" "0.1.0"]}]
          (handler.handle-message msg nil)
          ;; Should update state with session
          (assert.equals "test-session-123" state-data.conn.session)
          ;; Should log connection info
          (assert.equals 1 (length log-calls))
          (assert.equals :info (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)
                message "Connected to Grapple v0.1.0 running Janet v1.37.0 as session test-session-123"]
            (assert.is_table lines)
            (assert.equals 1 (length lines))
            (assert.equals message (. lines 1))))))

    (it "handles env.eval messages with nil value"
      (fn []
        (let [msg {:op "env.eval" :val nil}]
          (handler.handle-message msg nil)
          ;; Should not log anything
          (assert.equals 0 (length log-calls)))))

    (it "handles env.eval messages with stdout"
      (fn []
        (let [msg {:op "env.eval" :tag "out" :ch "out" :val "Hello, world!"}]
          (handler.handle-message msg nil)
          ;; Should log to stdout
          (assert.equals 1 (length log-calls))
          (assert.equals :stdout (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Hello, world!" (. lines 1))))))

    (it "handles env.eval messages with stderr"
      (fn []
        (let [msg {:op "env.eval" :tag "out" :ch "err" :val "Error occurred"}]
          (handler.handle-message msg nil)
          ;; Should log to stderr
          (assert.equals 1 (length log-calls))
          (assert.equals :stderr (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Error occurred" (. lines 1))))))

    (it "handles env.eval messages with return value"
      (fn []
        (let [msg {:op "env.eval" :tag "ret" :val "42"}]
          (handler.handle-message msg {})
          ;; Should log to result
          (assert.equals 1 (length log-calls))
          (assert.equals :result (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "42" (. lines 1))))))

    (it "handles env.eval messages with note"
      (fn []
        (let [msg {:op "env.eval" :tag "note" :val "Re-evaluating dependents of x: y, z"}]
          (handler.handle-message msg {})
          ;; Should log to note section
          (assert.equals 1 (length log-calls))
          (assert.equals :note (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Re-evaluating dependents of x: y, z" (. lines 1))))))

    (it "handles env.load messages like env.eval"
      (fn []
        (let [msg {:op "env.load" :tag "ret" :val "loaded"}]
          (handler.handle-message msg {})
          ;; Should log to result
          (assert.equals 1 (length log-calls))
          (assert.equals :result (. (. log-calls 1) :sec)))))

    (it "handles dbg.brk.add response"
      (fn []
        (let [msg {:op "dbg.brk.add"
                   :tag "ret"
                   :janet/bp-id 0}
              opts {:bufnr 1
                    :file-path "./test.janet"
                    :line 10}]
          (handler.handle-message msg opts)
          ;; Should log breakpoint added to debug section
          (assert.equals 1 (length log-calls))
          (assert.equals :debug (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Added breakpoint at ./test.janet:10" (. lines 1))))))

    (it "handles dbg.brk.rem response"
      (fn []
        (let [msg {:op "dbg.brk.rem"
                   :tag "ret"
                   :janet/bp-id 0}
              opts {:sign-id 123}]
          (handler.handle-message msg opts)
          ;; Should log breakpoint removed to debug section
          (assert.equals 1 (length log-calls))
          (assert.equals :debug (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Removed breakpoint at ./test.janet:10" (. lines 1))))))

    (it "handles dbg.brk.clr response"
      (fn []
        (let [msg {:op "dbg.brk.clr"
                   :tag "ret"}
              opts {}]
          (handler.handle-message msg opts)
          ;; Should log all breakpoints cleared to debug section
          (assert.equals 1 (length log-calls))
          (assert.equals :debug (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Cleared all breakpoints" (. lines 1))))))

    (it "handles dbg.insp.stk response with stack frames"
      (fn []
        (let [msg {:op "dbg.insp.stk"
                   :tag "ret"
                   :val "Stack frame data..."}
              opts {}]
          (handler.handle-message msg opts)
          ;; Should log stack frames to result section
          (assert.equals 1 (length log-calls))
          (assert.equals :result (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Stack frame data..." (. lines 1))))))

    (it "handles dbg.insp.stk response without stack frames"
      (fn []
        (let [msg {:op "dbg.insp.stk"
                   :tag "ret"}
              opts {}]
          (handler.handle-message msg opts)
          ;; Should log no frames message to debug section
          (assert.equals 1 (length log-calls))
          (assert.equals :debug (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "No stack frames available" (. lines 1))))))

    (it "handles debug signal within env.eval"
      (fn []
        (let [msg {:op "env.eval"
                   :tag "sig"
                   :val "debug"
                   :janet/path "./test.janet"
                   :janet/line 10}
              opts {}]
          (handler.handle-message msg opts)
          ;; Should log pause message to debug section (2 messages: pause + instructions)
          (assert.equals 2 (length log-calls))
          (assert.equals :debug (. (. log-calls 1) :sec))
          (assert.equals :debug (. (. log-calls 2) :sec))
          (let [line1 (. (. log-calls 1) :lines)
                line2 (. (. log-calls 2) :lines)]
            (assert.equals "Paused at breakpoint at ./test.janet:10" (. line1 1))
            (assert.equals "Use <localleader>dis to inspect stack, <localleader>dsc to continue" (. line2 1))))))
    (it "handles error messages"
      (fn []
        (let [msg {:tag "err"
                   :val "Compilation error"
                   :janet/path "/path/to/file.janet"
                   :janet/line 10
                   :janet/col 5}]
          (handler.handle-message msg nil)
          ;; Should log error with location
          (assert.equals 2 (length log-calls))
          (assert.equals :error (. (. log-calls 1) :sec))
          (assert.equals :error (. (. log-calls 2) :sec))
          (let [line1 (. (. log-calls 1) :lines)
                line2 (. (. log-calls 2) :lines)
                expected-location " in /path/to/file.janet on line 10 at col 5"]
            (assert.equals "Compilation error" (. line1 1))
            (assert.equals expected-location (. line2 1))))))

    (it "handles unrecognized messages"
      (fn []
        (let [msg {:op "unknown.op"}]
          (handler.handle-message msg nil)
          ;; Should log error
          (assert.equals 1 (length log-calls))
          (assert.equals :error (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals "Unrecognised message" (. lines 1))))))

    (it "handles nil messages gracefully"
      (fn []
        (handler.handle-message nil nil)
        ;; Should not crash or log anything
        (assert.equals 0 (length log-calls))))))

(local {: describe : it : before_each : after_each} (require :plenary.busted))
(local assert (require :luassert.assert))

;; Mock the log module before requiring request
(var log-calls [])
(local mock-log
  {:append (fn [sec lines]
             (table.insert log-calls {:sec sec :lines lines}))})

;; Store original log module if it exists
(local original-log (. package.loaded :grapple.client.log))

;; Install mock
(tset package.loaded :grapple.client.log mock-log)

;; Now require request (it will get the mocked log)
(local request (require :grapple.client.request))

(describe "sess-new"
  (fn []
    (it "sends sess.new message with action"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:action (fn [] "test-action")}]
          (request.sess-new conn opts)
          (assert.equals "sess.new" sent-msg.op)
          (assert.equals opts.action sent-action))))))

(describe "sess-end"
  (fn []
    (it "sends sess.end message with action"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:action (fn [] "test-action")}]
          (request.sess-end conn opts)
          (assert.equals "sess.end" sent-msg.op)
          (assert.equals opts.action sent-action))))

    (it "sends sess.end message with nil action when opts has no action"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {}]
          (request.sess-end conn opts)
          (assert.equals "sess.end" sent-msg.op)
          (assert.is_nil sent-action))))))

(describe "sess-list"
  (fn []
    (it "sends sess.list message with action"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:action (fn [] "test-action")}]
          (request.sess-list conn opts)
          (assert.equals "sess.list" sent-msg.op)
          (assert.equals opts.action sent-action))))))

(describe "serv-info"
  (fn []
    (it "sends serv.info message with action"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:action (fn [] "test-action")}]
          (request.serv-info conn opts)
          (assert.equals "serv.info" sent-msg.op)
          (assert.equals opts.action sent-action))))))

(describe "serv-stop"
  (fn []
    (it "sends serv.stop message with action"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:action (fn [] "test-action")}]
          (request.serv-stop conn opts)
          (assert.equals "serv.stop" sent-msg.op)
          (assert.equals opts.action sent-action))))))

(describe "serv-rest"
  (fn []
    (before_each
      (fn []
        (set log-calls [])))

    (it "logs error that serv.rest is not supported"
      (fn []
        (let [conn {}
              opts {}]
          (request.serv-rest conn opts)
          ;; Should have logged an error
          (assert.equals 1 (length log-calls))
          (assert.equals :error (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals 1 (length lines))
            (assert.equals "serv.rest is not supported" (. lines 1))))))))

(describe "env-eval"
  (fn []
    (before_each
      (fn []
        (set log-calls [])))

    (it "sends env.eval message with code and position"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:code "(+ 1 2)"
                    :file-path "/path/to/file.janet"
                    :range {:start [10 5]}
                    :action (fn [] "test-action")}]
          (request.env-eval conn opts)
          (assert.equals "env.eval" sent-msg.op)
          (assert.equals "(+ 1 2)" sent-msg.code)
          (assert.equals "/path/to/file.janet" sent-msg.ns)
          (assert.equals 10 sent-msg.line)
          (assert.equals 5 sent-msg.col)
          (assert.equals opts.action sent-action)
          ;; Should have logged the input
          (assert.equals 1 (length log-calls))
          (assert.equals :input (. (. log-calls 1) :sec)))))

    (it "uses default line and col when range not provided"
      (fn []
        (var sent-msg nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg))}
              opts {:code "(print 'hello')"
                    :file-path "/path/to/file.janet"
                    :action (fn [] "test-action")}]
          (request.env-eval conn opts)
          (assert.equals 1 sent-msg.line)
          (assert.equals 1 sent-msg.col))))

    (it "uses default col when range has no start col"
      (fn []
        (var sent-msg nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg))}
              opts {:code "(print 'hello')"
                    :file-path "/path/to/file.janet"
                    :range {:start [5]}
                    :action (fn [] "test-action")}]
          (request.env-eval conn opts)
          (assert.equals 5 sent-msg.line)
          (assert.equals 1 sent-msg.col))))))

(describe "env-load"
  (fn []
    (it "sends env.load message with file path"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:file-path "/path/to/file.janet"
                    :action (fn [] "test-action")}]
          (request.env-load conn opts)
          (assert.equals "env.load" sent-msg.op)
          (assert.equals "/path/to/file.janet" sent-msg.path)
          (assert.equals opts.action sent-action))))))

(describe "env-stop"
  (fn []
    (before_each
      (fn []
        (set log-calls [])))

    (it "logs error that env.stop is not supported"
      (fn []
        (let [conn {}
              opts {}]
          (request.env-stop conn opts)
          ;; Should have logged an error
          (assert.equals 1 (length log-calls))
          (assert.equals :error (. (. log-calls 1) :sec))
          (let [lines (. (. log-calls 1) :lines)]
            (assert.equals 1 (length lines))
            (assert.equals "env.stop is not supported" (. lines 1))))))))

(describe "env-doc"
  (fn []
    (it "sends env.doc message with symbol and namespace"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:code "defn"
                    :file-path "/path/to/file.janet"
                    :action (fn [] "test-action")}]
          (request.env-doc conn opts)
          (assert.equals "env.doc" sent-msg.op)
          (assert.equals "defn" sent-msg.sym)
          (assert.equals "/path/to/file.janet" sent-msg.ns)
          (assert.equals opts.action sent-action))))))

(describe "env-cmpl"
  (fn []
    (it "sends env.cmpl message with symbol and namespace"
      (fn []
        (var sent-msg nil)
        (var sent-action nil)
        (let [conn {:send (fn [msg action]
                            (set sent-msg msg)
                            (set sent-action action))}
              opts {:code "def"
                    :file-path "/path/to/file.janet"
                    :action (fn [] "test-action")}]
          (request.env-cmpl conn opts)
          (assert.equals "env.cmpl" sent-msg.op)
          (assert.equals "def" sent-msg.sym)
          (assert.equals "/path/to/file.janet" sent-msg.ns)
          (assert.equals opts.action sent-action))))))

;; Restore original log module after all tests
(tset package.loaded :grapple.client.log original-log)

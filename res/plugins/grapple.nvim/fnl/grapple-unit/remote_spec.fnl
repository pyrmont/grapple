(local {: describe : it : before_each} (require :plenary.busted))
(local assert (require :luassert.assert))

;; Mock dependencies before requiring remote
(var uuid-counter 0)
(var log-calls [])
(var sock-writes [])
(var net-connect-opts nil)

(local mock-uuid
  {:v4 (fn []
         (set uuid-counter (+ uuid-counter 1))
         (.. "test-uuid-" uuid-counter))})

(local mock-log
  {:dbg (fn [tag data]
          (table.insert log-calls {:tag tag :data data}))})

(local mock-client
  {:schedule (fn [f] nil)  ; Don't actually schedule
   :schedule-wrap (fn [f] f)  ; Return function as-is
   :wrap (fn [f] f)})  ; Return function as-is

(local mock-sock
  {:write (fn [self data]
            (table.insert sock-writes data))
   :read_start (fn [self cb] nil)})  ; Don't actually start reading

(local mock-net
  {:connect (fn [opts]
              (set net-connect-opts opts)
              {:sock mock-sock
               :destroy (fn [] nil)})})

(local mock-transport
  {:make-decode (fn [] (fn [chunk] []))  ; Return empty array of messages
   :encode (fn [msg] (.. "ENCODED:" (vim.inspect msg)))})

;; Use real nfnl instead of mocking it
(local n (require :nfnl.core))

;; Install mocks
(tset package.loaded :conjure.uuid mock-uuid)
(tset package.loaded :conjure.log mock-log)
(tset package.loaded :conjure.client mock-client)
(tset package.loaded :conjure.net mock-net)
(tset package.loaded :grapple.transport mock-transport)
(tset package.loaded :conjure.nfnl.core n)

;; Now require remote
(local remote (require :grapple.remote))

(describe "connect"
  (fn []
    (before_each
      (fn []
        (set uuid-counter 0)
        (set log-calls [])
        (set sock-writes [])
        (set net-connect-opts nil)))

    (it "creates connection with initial structure"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})]
          ;; Should have send function
          (assert.is_function conn.send)
          ;; Should have decode function
          (assert.is_function conn.decode)
          ;; Should have lang
          (assert.equals "janet" conn.lang)
          ;; Should have msgs table
          (assert.is_table conn.msgs)
          ;; Should have queue array
          (assert.is_table conn.queue)
          ;; Should have session (initially nil)
          (assert.is_nil conn.session)
          ;; Should have sock from net.connect
          (assert.equals mock-sock conn.sock)
          ;; Should have destroy from net.connect
          (assert.is_function conn.destroy))))

    (it "calls net.connect with correct options"
      (fn []
        (remote.connect {:host "192.168.1.1"
                        :port "8080"
                        :lang "janet"
                        :on-success (fn [] nil)
                        :on-failure (fn [err] nil)
                        :on-error (fn [err] nil)
                        :on-message (fn [msg action] nil)})
        ;; Should call net.connect with host and port
        (assert.equals "192.168.1.1" net-connect-opts.host)
        (assert.equals "8080" net-connect-opts.port)
        ;; Should have callback
        (assert.is_function net-connect-opts.cb)))

    (it "send adds UUID to message"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}]
          (conn.send msg (fn [] nil))
          ;; Should have UUID
          (assert.equals "test-uuid-1" msg.id))))

    (it "send adds lang to message"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}]
          (conn.send msg (fn [] nil))
          ;; Should have lang
          (assert.equals "janet" msg.lang))))

    (it "send adds session to message when session exists"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}]
          ;; Set session
          (tset conn :session "test-session-123")
          (conn.send msg (fn [] nil))
          ;; Should have session
          (assert.equals "test-session-123" msg.sess))))

    (it "send does not add session when session is nil"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}]
          (conn.send msg (fn [] nil))
          ;; Should not have session
          (assert.is_nil msg.sess))))

    (it "send stores message and opts in msgs map"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}
              action-fn (fn [] "test-action")
              opts {:action action-fn}]
          (conn.send msg opts)
          ;; Should store in msgs with UUID key
          (let [stored (. conn.msgs "test-uuid-1")]
            (assert.is_table stored)
            (assert.equals msg stored.msg)
            (assert.equals opts stored.opts)))))

    (it "send writes encoded message to socket"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}]
          (conn.send msg (fn [] nil))
          ;; Should have written to socket
          (assert.equals 1 (length sock-writes))
          ;; Should start with "ENCODED:" (from our mock)
          (let [pos (string.find (. sock-writes 1) "ENCODED:" 1 true)]
            (assert.is_not_nil pos)))))

    (it "send logs debug information"
      (fn []
        (let [conn (remote.connect {:host "localhost"
                                    :port "9365"
                                    :lang "janet"
                                    :on-success (fn [] nil)
                                    :on-failure (fn [err] nil)
                                    :on-error (fn [err] nil)
                                    :on-message (fn [msg opts] nil)})
              msg {:op "env.eval" :code "(+ 1 2)"}]
          (conn.send msg (fn [] nil))
          ;; Should have logged
          (assert.is_true (> (length log-calls) 0))
          ;; Should have "send" tag
          (var found-send false)
          (each [_ call (ipairs log-calls)]
            (when (= "send" call.tag)
              (set found-send true)))
          (assert.is_true found-send))))))

(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local n (require :conjure.nfnl.core))
(local state (require :grapple.client.state))

(describe "get"
  (fn []
    (it "returns the initial state"
      (fn []
        (let [initial (state.get)]
          ;; Should be a table
          (assert.is_table initial)
          ;; Should have conn key initialized to nil
          (assert.is_nil initial.conn))))

    (it "returns a specific key from state"
      (fn []
        (let [conn (state.get :conn)]
          ;; Initial conn should be nil
          (assert.is_nil conn))))

    (it "allows updating state with assoc"
      (fn []
        ;; Update the conn field
        (n.assoc (state.get) :conn {:host "localhost" :port 5555})
        ;; Verify the update
        (let [conn (state.get :conn)]
          (assert.is_table conn)
          (assert.equals "localhost" conn.host)
          (assert.equals 5555 conn.port))))

    (it "persists state across calls"
      (fn []
        ;; Set a value
        (n.assoc (state.get) :conn {:session "test-session"})
        ;; Get it back in a different call
        (let [conn1 (state.get :conn)
              conn2 (state.get :conn)]
          (assert.equals "test-session" conn1.session)
          (assert.equals "test-session" conn2.session)
          ;; Should be the same table reference
          (assert.equals conn1 conn2))))

    (it "allows storing different keys"
      (fn []
        ;; Store multiple keys
        (n.assoc (state.get) :server-pid 12345)
        (n.assoc (state.get) :log-sec "output")
        ;; Verify both are stored
        (assert.equals 12345 (state.get :server-pid))
        (assert.equals "output" (state.get :log-sec))))

    (it "returns nil for non-existent keys"
      (fn []
        (let [missing (state.get :does-not-exist)]
          (assert.is_nil missing))))

    (it "can update nested connection properties"
      (fn []
        ;; Set initial connection
        (n.assoc (state.get) :conn {:host "localhost" :port 5555})
        ;; Update to add session
        (n.assoc (state.get :conn) :session "abc123")
        ;; Verify both original and new properties exist
        (let [conn (state.get :conn)]
          (assert.equals "localhost" conn.host)
          (assert.equals 5555 conn.port)
          (assert.equals "abc123" conn.session))))

    (it "can clear state by setting to nil"
      (fn []
        ;; Set a connection
        (n.assoc (state.get) :conn {:host "localhost"})
        (assert.is_table (state.get :conn))
        ;; Clear it
        (n.assoc (state.get) :conn nil)
        (assert.is_nil (state.get :conn))))

    (it "maintains separate keys independently"
      (fn []
        ;; Set multiple keys
        (n.assoc (state.get) :conn {:host "localhost"})
        (n.assoc (state.get) :server-pid 99999)
        ;; Clear one key
        (n.assoc (state.get) :conn nil)
        ;; Other key should remain
        (assert.is_nil (state.get :conn))
        (assert.equals 99999 (state.get :server-pid))))

    (it "has token field initialized to nil"
      (fn []
        ;; Token should be a valid key in initial state
        (let [initial (state.get)]
          ;; Token should exist as a key (even if nil)
          (assert.is_nil initial.token))))

    (it "can store and retrieve authentication token"
      (fn []
        ;; Set a token
        (n.assoc (state.get) :token "abc123token")
        ;; Retrieve it
        (let [token (state.get :token)]
          (assert.equals "abc123token" token))
        ;; Clear it
        (n.assoc (state.get) :token nil)
        (assert.is_nil (state.get :token))))))

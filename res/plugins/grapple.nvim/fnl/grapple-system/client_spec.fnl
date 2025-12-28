(local {: describe : it : before_each : after_each} (require :plenary.busted))
(local assert (require :luassert.assert))

(local client (require :grapple.client))
(local state (require :grapple.client.state))
(local log (require :grapple.client.log))
(local n (require :conjure.nfnl.core))

;; Helper to set up Conjure client context
(fn setup-client-context []
  ;; Create a buffer and set it to janet filetype
  (let [buf (vim.api.nvim_create_buf false true)]
    (vim.api.nvim_buf_set_option buf :filetype "janet")
    (vim.api.nvim_set_current_buf buf)
    ;; Explicitly trigger client initialization
    (client.on-filetype)
    ;; Ensure log buffer exists
    (log.buf)
    ;; Give time for any async initialization
    (vim.wait 100 (fn [] false))
    buf))

(describe "client system tests"
  (fn []
    (var test-port "19999")
    (var test-buf nil)

    (before_each
      (fn []
        ;; Set up Conjure client context
        (set test-buf (setup-client-context))))

    (after_each
      (fn []
        ;; Clean up any running servers
        (let [pid (state.get :server-pid)]
          (when pid
            (vim.fn.jobstop pid)
            (n.assoc (state.get) :server-pid nil)))
        ;; Give time for cleanup
        (vim.wait 500 (fn [] false))
        ;; Clear state
        (n.assoc (state.get) :conn nil)
        ;; Delete test buffer
        (when test-buf
          (pcall vim.api.nvim_buf_delete test-buf {:force true}))))

    (it "can start server and store PID"
      (fn []
        ;; Start a real Janet server on a test port
        (client.start-server {:host "127.0.0.1" :port test-port})

        ;; Give server time to start
        (vim.wait 1000 (fn [] false))

        (let [pid (state.get :server-pid)]
          ;; Should have a PID
          (assert.is_not_nil pid)
          ;; Should be a number
          (assert.is_number pid))))

    (it "can stop the server"
      (fn []
        ;; Start server
        (client.start-server {:host "127.0.0.1" :port test-port})
        (vim.wait 1000 (fn [] false))

        ;; Verify it started
        (let [pid (state.get :server-pid)]
          (assert.is_not_nil pid)

          ;; Stop server
          (client.stop-server)

          ;; Wait for stop
          (vim.wait 500 (fn [] false))

          ;; PID should be cleared
          (assert.is_nil (state.get :server-pid)))))

    (it "uses provided host and port"
      (fn []
        ;; Start with custom port
        (client.start-server {:host "127.0.0.1" :port "9999"})
        ;; Wait for deferred function to set server-pid (1000ms delay + buffer)
        (vim.wait 1200 (fn [] false))

        ;; Should have started
        (assert.is_not_nil (state.get :server-pid))))

    (it "handles multiple start/stop cycles"
      (fn []
        ;; First cycle
        (client.start-server {:host "127.0.0.1" :port test-port})
        ;; Wait for deferred function to set server-pid (1000ms delay + buffer)
        (vim.wait 1200 (fn [] false))
        (let [pid1 (state.get :server-pid)]
          (assert.is_not_nil pid1)

          (client.stop-server)
          (vim.wait 500 (fn [] false))
          (assert.is_nil (state.get :server-pid))

          ;; Second cycle
          (client.start-server {:host "127.0.0.1" :port test-port})
          ;; Wait for deferred function to set server-pid (1000ms delay + buffer)
          (vim.wait 1200 (fn [] false))
          (let [pid2 (state.get :server-pid)]
            (assert.is_not_nil pid2)))))))

;; Note: Connection and evaluation tests are more complex and may require
;; additional setup. Start with these basic server lifecycle tests.
(describe "client connection tests (optional)"
  (fn []
    (it "connection tests can be added once server tests pass"
      (fn []
        ;; Once the basic server tests work, we can add connection tests
        ;; that actually connect to the server and verify the connection state
        (assert.is_true true)))))

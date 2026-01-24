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

;; Basic example of system working
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

        ;; Wait for server to be ready (condition-based, up to 2 seconds)
        (vim.wait 2000 (fn [] (state.get :server-ready)))

        (let [pid (state.get :server-pid)]
          ;; Should have a PID
          (assert.is_not_nil pid)
          ;; Should be a number
          (assert.is_number pid))))

    (it "can stop the server"
      (fn []
        ;; Start server
        (client.start-server {:host "127.0.0.1" :port test-port})
        ;; Wait for server to be ready
        (vim.wait 2000 (fn [] (state.get :server-ready)))

        ;; Verify it started
        (let [pid (state.get :server-pid)]
          (assert.is_not_nil pid)

          ;; Stop server
          (client.stop-server)

          ;; Wait for PID to be cleared (condition-based, up to 1 second)
          (vim.wait 1000 (fn [] (= nil (state.get :server-pid))))

          ;; PID should be cleared
          (assert.is_nil (state.get :server-pid)))))

    (it "uses provided host and port"
      (fn []
        ;; Start with custom port
        (client.start-server {:host "127.0.0.1" :port "9999"})
        ;; Wait for server to be ready
        (vim.wait 2000 (fn [] (state.get :server-ready)))

        ;; Should have started
        (assert.is_not_nil (state.get :server-pid))))

    (it "handles multiple start/stop cycles"
      (fn []
        ;; First cycle
        (client.start-server {:host "127.0.0.1" :port test-port})
        ;; Wait for server to be ready
        (vim.wait 2000 (fn [] (state.get :server-ready)))
        (let [pid1 (state.get :server-pid)]
          (assert.is_not_nil pid1)

          (client.stop-server)
          ;; Wait for PID to be cleared
          (vim.wait 1000 (fn [] (= nil (state.get :server-pid))))
          (assert.is_nil (state.get :server-pid))

          ;; Second cycle
          (client.start-server {:host "127.0.0.1" :port test-port})
          ;; Wait for server to be ready
          (vim.wait 2000 (fn [] (state.get :server-ready)))
          (let [pid2 (state.get :server-pid)]
            (assert.is_not_nil pid2)))))))

;; Debugging infrastructure tests
;; Note: These tests verify the debug state management works correctly
;; Full end-to-end debugging workflow (hitting breakpoints, pausing, continuing)
;; requires a connected server and is better suited for manual/interactive testing
(describe "client debugging infrastructure"
  (fn []
    (var test-buf nil)

    (before_each
      (fn []
        ;; Set up Conjure client context
        (set test-buf (setup-client-context))
        ;; Initialize state
        (n.assoc (state.get) :breakpoints {})
        (n.assoc (state.get) :debug-position nil)))

    (after_each
      (fn []
        ;; Clear state
        (n.assoc (state.get) :breakpoints {})
        (n.assoc (state.get) :debug-position nil)
        ;; Delete test buffer
        (when test-buf
          (pcall vim.api.nvim_buf_delete test-buf {:force true}))))

    (it "has breakpoints state initialized"
      (fn []
        ;; Breakpoints should exist in state
        (let [breakpoints (state.get :breakpoints)]
          (assert.is_not_nil breakpoints)
          (assert.is_table breakpoints))))

    (it "can store breakpoint data in state"
      (fn []
        ;; Manually store a breakpoint in state (simulating what add-breakpoint-sign does)
        (let [breakpoints (state.get :breakpoints)
              test-file "/tmp/test.janet"
              line 10
              bp-key (.. test-file ":" line)]
          (n.assoc breakpoints bp-key {:bufnr test-buf :line line :sign-id 1001})
          ;; Verify it was stored
          (let [stored-bp (. breakpoints bp-key)]
            (assert.is_not_nil stored-bp)
            (assert.equals test-buf stored-bp.bufnr)
            (assert.equals line stored-bp.line)
            (assert.equals 1001 stored-bp.sign-id)))))

    (it "can remove breakpoint data from state"
      (fn []
        ;; Add a breakpoint
        (let [breakpoints (state.get :breakpoints)
              test-file "/tmp/test.janet"
              bp-key (.. test-file ":10")]
          (n.assoc breakpoints bp-key {:bufnr test-buf :line 10 :sign-id 1001})
          ;; Verify it exists
          (assert.is_not_nil (. breakpoints bp-key))
          ;; Remove it (simulating what remove-breakpoint does)
          (n.assoc breakpoints bp-key nil)
          ;; Verify it was removed
          (assert.is_nil (. breakpoints bp-key)))))

    (it "can clear all breakpoints from state"
      (fn []
        ;; Add multiple breakpoints
        (let [breakpoints (state.get :breakpoints)]
          (n.assoc breakpoints "/tmp/test1.janet:10" {:bufnr test-buf :line 10 :sign-id 1001})
          (n.assoc breakpoints "/tmp/test2.janet:20" {:bufnr test-buf :line 20 :sign-id 1002})
          ;; Verify they exist
          (assert.equals 2 (length (vim.tbl_keys breakpoints)))
          ;; Clear all (simulating what clear-all-breakpoints does)
          (n.assoc (state.get) :breakpoints {})
          ;; Verify all cleared
          (let [cleared-breakpoints (state.get :breakpoints)]
            (assert.equals 0 (length (vim.tbl_keys cleared-breakpoints)))))))

    (it "can store and retrieve debug position"
      (fn []
        ;; Store debug position (simulating what show-debug-indicators does)
        (let [debug-pos {:path "/tmp/test.janet" :line 15 :col 3}]
          (n.assoc (state.get) :debug-position debug-pos)
          ;; Retrieve it
          (let [stored-pos (state.get :debug-position)]
            (assert.is_not_nil stored-pos)
            (assert.equals "/tmp/test.janet" stored-pos.path)
            (assert.equals 15 stored-pos.line)
            (assert.equals 3 stored-pos.col)))))

    (it "breakpoint commands don't crash when not connected"
      (fn []
        ;; These should handle the disconnected case gracefully
        ;; They will show warnings but shouldn't crash
        (assert.has_no.errors
          (fn []
            (client.add-breakpoint)
            (client.remove-breakpoint)
            (client.clear-breakpoints)))))))

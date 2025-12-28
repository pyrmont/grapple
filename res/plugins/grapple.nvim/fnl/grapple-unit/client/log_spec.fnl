(local {: describe : it : before_each} (require :plenary.busted))
(local assert (require :luassert.assert))
(local client-log (require :grapple.client.log))

;; Helper to get extmarks in a buffer
(fn get-extmarks [buf ns]
  (vim.api.nvim_buf_get_extmarks buf ns 0 -1 {:details true}))

;; Helper to count extmarks with a specific highlight group
(fn count-extmarks-with-hl [buf ns hl-group]
  (let [marks (get-extmarks buf ns)
        matching []]
    (each [_ mark (ipairs marks)]
      (let [[id row col opts] mark]
        (when (= opts.hl_group hl-group)
          (table.insert matching mark))))
    (length matching)))

;; Helper to get buffer lines
(fn get-buf-lines [buf]
  (vim.api.nvim_buf_get_lines buf 0 -1 false))

(describe "buf"
  (fn []
    (it "returns a buffer number"
      (fn []
        ;; Call buf to get the log buffer
        (let [buf-num (client-log.buf)]
          ;; Should return a number
          (assert.is_number buf-num)
          ;; Should be a valid buffer
          (assert.is_true (vim.api.nvim_buf_is_valid buf-num)))))))

(describe "append"
  (fn []
    (it "appends lines to the log buffer"
      (fn []
        ;; Get the log buffer
        (let [buf-num (client-log.buf)
              initial-line-count (vim.api.nvim_buf_line_count buf-num)]
          ;; Append some info lines
          (client-log.append :info ["test message 1" "test message 2"] {})
          ;; Buffer should have more lines now
          (let [new-line-count (vim.api.nvim_buf_line_count buf-num)]
            (assert.is_true (> new-line-count initial-line-count))))))

    (it "adds section headers when section changes"
      (fn []
        (let [buf-num (client-log.buf)
              lines-before (get-buf-lines buf-num)]
          ;; Append to info section
          (client-log.append :info ["info message"] {})
          (let [lines-after (get-buf-lines buf-num)
                new-lines (length lines-after)]
            ;; Should have added header + message
            (assert.is_true (> new-lines (length lines-before)))
            ;; Check that header was added
            (var found-header false)
            (each [_ line (ipairs lines-after)]
              (when (line:match "info")
                (set found-header true)))
            (assert.is_true found-header)))))

    (it "does not repeat headers for same section"
      (fn []
        (let [buf-num (client-log.buf)]
          ;; Append to stdout section twice
          (client-log.append :stdout ["first stdout"] {})
          (let [lines-after-first (get-buf-lines buf-num)
                count-after-first (length lines-after-first)]
            (client-log.append :stdout ["second stdout"] {})
            (let [lines-after-second (get-buf-lines buf-num)
                  count-after-second (length lines-after-second)]
              ;; Should only add 1 line (not a header)
              (assert.equals (+ count-after-first 1) count-after-second))))))

    (it "highlights info content with Title"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")]
          ;; Append info message
          (client-log.append :info ["highlighted info"] {})
          ;; Check for Title highlight
          (assert.is_true (> (count-extmarks-with-hl buf-num ns "Title") 0)))))

    (it "highlights error content with ErrorMsg"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")]
          ;; Append error message
          (client-log.append :error ["error occurred"] {})
          ;; Check for ErrorMsg highlight
          (assert.is_true (> (count-extmarks-with-hl buf-num ns "ErrorMsg") 0)))))

    (it "highlights stdout content with String"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")]
          ;; Append stdout message
          (client-log.append :stdout ["program output"] {})
          ;; Check for String highlight
          (assert.is_true (> (count-extmarks-with-hl buf-num ns "String") 0)))))

    (it "highlights stderr content with WarningMsg"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")]
          ;; Append stderr message
          (client-log.append :stderr ["warning output"] {})
          ;; Check for WarningMsg highlight
          (assert.is_true (> (count-extmarks-with-hl buf-num ns "WarningMsg") 0)))))

    (it "highlights note content with Special"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")]
          ;; Append note message
          (client-log.append :note ["Re-evaluating dependents of x: y, z"] {})
          ;; Check for Special highlight
          (assert.is_true (> (count-extmarks-with-hl buf-num ns "Special") 0)))))

    (it "does not add highlights for input content"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")
              title-before (count-extmarks-with-hl buf-num ns "Title")
              string-before (count-extmarks-with-hl buf-num ns "String")]
          ;; Append input (should not be highlighted)
          (client-log.append :input ["(+ 1 2)"] {})
          (let [title-after (count-extmarks-with-hl buf-num ns "Title")
                string-after (count-extmarks-with-hl buf-num ns "String")]
            ;; Should have added header extmark (Comment) but not content highlight
            ;; Title and String counts should be unchanged
            (assert.equals title-before title-after)
            (assert.equals string-before string-after)))))

    (it "does not add highlights for result content"
      (fn []
        (let [buf-num (client-log.buf)
              ns (vim.api.nvim_create_namespace "grapple-log")
              title-before (count-extmarks-with-hl buf-num ns "Title")
              string-before (count-extmarks-with-hl buf-num ns "String")
              warning-before (count-extmarks-with-hl buf-num ns "WarningMsg")
              error-before (count-extmarks-with-hl buf-num ns "ErrorMsg")]
          ;; Append result (should not be highlighted)
          (client-log.append :result ["42"] {})
          ;; Result content should not have any of these highlights
          ;; (it will have Comment for the header, but not for content)
          (let [lines (get-buf-lines buf-num)
                ;; Find the line with "42"
                result-found (accumulate [found false
                                         _ line (ipairs lines)]
                               (or found (not= nil (line:match "42"))))]
            ;; Verify result was added
            (assert.is_true result-found)
            ;; But it shouldn't have content highlighting (only header has Comment)
            ;; Highlight counts should be unchanged
            (assert.equals title-before (count-extmarks-with-hl buf-num ns "Title"))
            (assert.equals string-before (count-extmarks-with-hl buf-num ns "String"))
            (assert.equals warning-before (count-extmarks-with-hl buf-num ns "WarningMsg"))
            (assert.equals error-before (count-extmarks-with-hl buf-num ns "ErrorMsg"))))))))

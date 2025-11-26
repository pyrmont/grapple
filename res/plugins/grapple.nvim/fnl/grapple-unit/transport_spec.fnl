(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local transport (require :grapple.transport))

(describe "encode"
  (fn []
    (it "encodes a simple message"
      (fn []
        (let [msg {:op "sess.new"}
              encoded (transport.encode msg)]
          ;; Should have 4-byte length prefix + JSON content
          (assert.is_true (> (length encoded) 4))
          ;; First 4 bytes are the length (little-endian)
          (let [b0 (string.byte encoded 1)
                b1 (string.byte encoded 2)
                b2 (string.byte encoded 3)
                b3 (string.byte encoded 4)
                len (+ b0
                       (bit.lshift b1 8)
                       (bit.lshift b2 16)
                       (bit.lshift b3 24))
                body (string.sub encoded 5)]
            ;; Length should match the JSON body length
            (assert.equals len (length body))
            ;; Body should be valid JSON
            (let [decoded (vim.json.decode body)]
              (assert.equals "sess.new" decoded.op))))))

    (it "encodes a message with multiple fields"
      (fn []
        (let [msg {:op "env.eval" :code "(+ 1 2)" :line 1 :col 1}
              encoded (transport.encode msg)
              body (string.sub encoded 5)
              decoded (vim.json.decode body)]
          (assert.equals "env.eval" decoded.op)
          (assert.equals "(+ 1 2)" decoded.code)
          (assert.equals 1 decoded.line)
          (assert.equals 1 decoded.col))))

    (it "encodes a message with nested data"
      (fn []
        (let [msg {:op "test" :data {:nested {:value 42}}}
              encoded (transport.encode msg)
              body (string.sub encoded 5)
              decoded (vim.json.decode body)]
          (assert.equals "test" decoded.op)
          (assert.equals 42 decoded.data.nested.value))))

    (it "handles empty message"
      (fn []
        (let [msg {}
              encoded (transport.encode msg)]
          ;; Should still have 4-byte prefix
          (assert.is_true (>= (length encoded) 4)))))))

(describe "make-decode"
  (fn []
    (it "decodes a single complete message"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "sess.new"}
              encoded (transport.encode msg)
              decoded (decode encoded)]
          (assert.equals 1 (length decoded))
          (assert.equals "sess.new" (. (. decoded 1) :op)))))

    (it "decodes multiple messages in one chunk"
      (fn []
        (let [decode (transport.make-decode)
              msg1 {:op "sess.new"}
              msg2 {:op "env.eval" :code "(+ 1 2)"}
              encoded (.. (transport.encode msg1) (transport.encode msg2))
              decoded (decode encoded)]
          (assert.equals 2 (length decoded))
          (assert.equals "sess.new" (. (. decoded 1) :op))
          (assert.equals "env.eval" (. (. decoded 2) :op))
          (assert.equals "(+ 1 2)" (. (. decoded 2) :code)))))

    (it "handles partial message - header only"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "sess.new"}
              encoded (transport.encode msg)
              part (string.sub encoded 1 4)] ; Full 4-byte header, no body
          ;; Should return empty array since we don't have the body yet
          (let [decoded (decode part)]
            (assert.equals 0 (length decoded))))))

    (it "handles partial message - header + partial body"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "sess.new"}
              encoded (transport.encode msg)
              part (string.sub encoded 1 8)] ; Header + some body
          ;; Should return empty array, waiting for rest
          (let [decoded (decode part)]
            (assert.equals 0 (length decoded))))))

    (it "completes partial message with second chunk"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "sess.new"}
              encoded (transport.encode msg)
              mid (math.floor (/ (length encoded) 2))
              part1 (string.sub encoded 1 mid)
              part2 (string.sub encoded (+ mid 1))]
          ;; First chunk returns nothing
          (let [decoded1 (decode part1)]
            (assert.equals 0 (length decoded1)))
          ;; Second chunk completes and returns the message
          (let [decoded2 (decode part2)]
            (assert.equals 1 (length decoded2))
            (assert.equals "sess.new" (. (. decoded2 1) :op))))))

    (it "handles message split at 4-byte boundaries"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "test" :value 123}
              encoded (transport.encode msg)]
          ;; Split at header boundary (4 bytes)
          (let [header (string.sub encoded 1 4)
                body (string.sub encoded 5)]
            ;; First chunk (header) returns nothing
            (assert.equals 0 (length (decode header)))
            ;; Second chunk (body) completes the message
            (let [results (decode body)]
              (assert.equals 1 (length results))
              (assert.equals "test" (. (. results 1) :op))
              (assert.equals 123 (. (. results 1) :value)))))))

    (it "handles multiple complete messages with partial"
      (fn []
        (let [decode (transport.make-decode)
              msg1 {:op "first"}
              msg2 {:op "second"}
              msg3 {:op "third"}
              encoded1 (transport.encode msg1)
              encoded2 (transport.encode msg2)
              encoded3 (transport.encode msg3)
              combined (.. encoded1 encoded2 (string.sub encoded3 1 5))]
          ;; Should decode first two messages
          (let [decoded (decode combined)]
            (assert.equals 2 (length decoded))
            (assert.equals "first" (. (. decoded 1) :op))
            (assert.equals "second" (. (. decoded 2) :op)))
          ;; Complete the third message
          (let [rest (string.sub encoded3 6)
                decoded (decode rest)]
            (assert.equals 1 (length decoded))
            (assert.equals "third" (. (. decoded 1) :op))))))

    (it "handles exact boundary splits"
      (fn []
        (let [decode (transport.make-decode)
              msg1 {:op "first"}
              msg2 {:op "second"}
              encoded1 (transport.encode msg1)
              encoded2 (transport.encode msg2)
              combined (.. encoded1 encoded2)]
          ;; Send first message exactly
          (let [decoded1 (decode encoded1)]
            (assert.equals 1 (length decoded1))
            (assert.equals "first" (. (. decoded1 1) :op)))
          ;; Send second message exactly
          (let [decoded2 (decode encoded2)]
            (assert.equals 1 (length decoded2))
            (assert.equals "second" (. (. decoded2 1) :op))))))

    (it "handles large message"
      (fn []
        (let [decode (transport.make-decode)
              ;; Create a message with a large string
              large-data (string.rep "x" 10000)
              msg {:op "large" :data large-data}
              encoded (transport.encode msg)
              decoded (decode encoded)]
          (assert.equals 1 (length decoded))
          (assert.equals "large" (. (. decoded 1) :op))
          (assert.equals 10000 (length (. (. decoded 1) :data))))))

    (it "maintains state across calls"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "test"}
              encoded (transport.encode msg)]
          ;; Split into 3 parts (header, partial body, rest of body)
          (let [len (length encoded)
                part1 (string.sub encoded 1 4)  ; Header
                part2 (string.sub encoded 5 6)  ; Partial body
                part3 (string.sub encoded 7)]    ; Rest
            ;; First two parts return nothing
            (assert.equals 0 (length (decode part1)))
            (assert.equals 0 (length (decode part2)))
            ;; Final part completes the message
            (let [result (decode part3)]
              (assert.equals 1 (length result))
              (assert.equals "test" (. (. result 1) :op)))))))

    (it "handles complex nested structures"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "complex"
                   :data {:array [1 2 3]
                          :nested {:a "hello"
                                   :b {:c [4 5 6]}}}}
              encoded (transport.encode msg)
              decoded (decode encoded)]
          (assert.equals 1 (length decoded))
          (let [result (. decoded 1)]
            (assert.equals "complex" result.op)
            (assert.equals 1 (. result.data.array 1))
            (assert.equals 2 (. result.data.array 2))
            (assert.equals 3 (. result.data.array 3))
            (assert.equals "hello" result.data.nested.a)
            (assert.equals 4 (. result.data.nested.b.c 1))))))

    (it "handles empty array accumulator correctly"
      (fn []
        (let [decode (transport.make-decode)
              msg {:op "test"}
              encoded (transport.encode msg)
              ;; Call decode with full message
              decoded1 (decode encoded)
              ;; Call again with another message
              decoded2 (decode encoded)]
          ;; Both should succeed independently
          (assert.equals 1 (length decoded1))
          (assert.equals 1 (length decoded2))
          (assert.equals "test" (. (. decoded1 1) :op))
          (assert.equals "test" (. (. decoded2 1) :op)))))))

(describe "round-trip"
  (fn []
    (it "encode then decode returns original message"
      (fn []
        (let [decode (transport.make-decode)
              original {:op "env.eval"
                        :code "(+ 1 2)"
                        :line 1
                        :col 5
                        :sess "abc123"}
              encoded (transport.encode original)
              decoded (decode encoded)
              result (. decoded 1)]
          (assert.equals original.op result.op)
          (assert.equals original.code result.code)
          (assert.equals original.line result.line)
          (assert.equals original.col result.col)
          (assert.equals original.sess result.sess))))))

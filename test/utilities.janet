(import /deps/testament :prefix "" :exit true)
(import ../lib/utilities :as util)

# Simple types (formatted as Janet literals)

(deftest primitive-nil
  (def actual (util/to-inspectable nil))
  (is (= "nil" actual)))

(deftest primitive-boolean-true
  (def actual (util/to-inspectable true))
  (is (= "true" actual)))

(deftest primitive-boolean-false
  (def actual (util/to-inspectable false))
  (is (= "false" actual)))

(deftest primitive-number
  (def actual (util/to-inspectable 42))
  (is (= "42" actual)))

(deftest primitive-string
  (def actual (util/to-inspectable "hello"))
  (is (= "\"hello\"" actual)))

(deftest symbol-conversion
  (def actual (util/to-inspectable 'foo))
  (is (= "foo" actual)))

(deftest keyword-conversion
  (def actual (util/to-inspectable :bar))
  (is (= ":bar" actual)))

(deftest buffer-conversion
  (def buf @"test buffer")
  (def actual (util/to-inspectable buf))
  (is (= "@\"test buffer\"" actual)))

# Arrays

(deftest array-empty
  (def actual (util/to-inspectable @[]))
  (def expect {:type "array" :count 0 :length 3 :els @[]})
  (is (== expect actual)))

(deftest array-simple
  (def actual (util/to-inspectable @[1 2 3]))
  (def expect {:type "array" :count 3 :length 8 :els @["1" "2" "3"]})
  (is (== expect actual)))

(deftest array-nested
  (def actual (util/to-inspectable @[@[1 2] @[3 4]]))
  (def expect {:type "array"
               :count 2
               :length 16
               :els @[{:type "array" :count 2 :length 6 :els @["1" "2"]}
                      {:type "array" :count 2 :length 6 :els @["3" "4"]}]})
  (is (== expect actual)))

# Tuples

(deftest tuple-empty
  (def actual (util/to-inspectable []))
  (def expect {:type "tuple" :count 0 :length 2 :els @[]})
  (is (== expect actual)))

(deftest tuple-simple
  (def actual (util/to-inspectable [1 2 3]))
  (def expect {:type "tuple" :count 3 :length 7 :els @["1" "2" "3"]})
  (is (== expect actual)))

# Tables

(deftest table-empty
  (def actual (util/to-inspectable @{}))
  (def expect {:type "table" :count 0 :length 3 :kvs @[]})
  (is (== expect actual)))

(deftest table-simple
  (def actual (util/to-inspectable @{:a 1 :b 2}))
  (is (= "table" (get actual :type)))
  (is (= 2 (get actual :count)))
  (def kvs (get actual :kvs))
  (is (= 4 (length kvs)))
  # Check that both keys are present (order may vary)
  (def keys (filter |(string/has-prefix? ":" $) kvs))
  (is (== (sorted keys) [":a" ":b"])))

# Structs

(deftest struct-empty
  (def actual (util/to-inspectable {}))
  (def expect {:type "struct" :count 0 :length 2 :kvs @[]})
  (is (== expect actual)))

(deftest struct-simple
  (def actual (util/to-inspectable {:a 1 :b 2}))
  (is (= "struct" (get actual :type)))
  (is (= 2 (get actual :count)))
  (def kvs (get actual :kvs))
  (is (= 4 (length kvs)))
  # Check that both keys are present (order may vary)
  (def keys (filter |(string/has-prefix? ":" $) kvs))
  (is (== (sorted keys) [":a" ":b"])))

# Nested structures

(deftest nested-array-of-tables
  (def actual (util/to-inspectable @[@{:x 1} @{:y 2}]))
  (is (= "array" (get actual :type)))
  (is (= 2 (length (get actual :els))))
  (def first-table (get-in actual [:els 0]))
  (is (= "table" (get first-table :type))))

# Circular references

(deftest circular-array
  (def arr @[1 2 3])
  (array/push arr arr)  # arr now contains itself
  (def actual (util/to-inspectable arr))
  (is (= "array" (get actual :type)))
  (is (= 4 (get actual :count)))
  (def last-val (get-in actual [:els 3]))
  (is (== {:type "circular" :to "array"} last-val)))

(deftest circular-table
  (def tbl @{:a 1 :b 2})
  (put tbl :self tbl)  # tbl now contains itself
  (def actual (util/to-inspectable tbl))
  (is (= "table" (get actual :type)))
  (is (= 3 (get actual :count)))
  # Find the :self value in the kvs array
  (def kvs (get actual :kvs))
  (def self-idx (find-index |(= ":self" $) kvs))
  (is (not (nil? self-idx)))
  (def self-val (get kvs (inc self-idx)))
  (is (== {:type "circular" :to "table"} self-val)))

# Deep nesting (exceeds depth limit)

(deftest depth-limit-default
  (var nested 0)
  (for i 0 15  # Create 15 levels of nesting (default limit is 10)
    (set nested @[nested]))
  (def actual (util/to-inspectable nested))
  # Should be able to descend 10 levels
  (var current actual)
  (for i 0 10
    (is (= "array" (get current :type)))
    (set current (get-in current [:els 0])))
  # At level 10, should hit truncation
  (is (== {:type "truncated"} current)))

(deftest depth-limit-custom
  (var nested 0)
  (for i 0 5
    (set nested @[nested]))
  (def actual (util/to-inspectable nested {:max-depth 3}))
  # Should be able to descend 3 levels
  (var current actual)
  (for i 0 3
    (is (= "array" (get current :type)))
    (set current (get-in current [:els 0])))
  # At level 3, should hit truncation
  (is (== {:type "truncated"} current)))

# Mixed types

(deftest mixed-types
  (def actual (util/to-inspectable @[1 "hello" :key 'sym true nil]))
  (is (= "array" (get actual :type)))
  (def values (get actual :els))
  (is (= "1" (get values 0)))
  (is (= "\"hello\"" (get values 1)))
  (is (= ":key" (get values 2)))
  (is (= "sym" (get values 3)))
  (is (= "true" (get values 4)))
  (is (= "nil" (get values 5))))

# Unprintable types

(deftest function-conversion
  (defn test-fn [] 42)
  (def actual (util/to-inspectable test-fn))
  (is (= "function" (get actual :type)))
  (is (string? (get actual :value)))
  (is (string/has-prefix? "<function" (get actual :value))))

(deftest fiber-conversion
  (def test-fiber (fiber/new (fn [] (yield 1) 2)))
  (def actual (util/to-inspectable test-fiber))
  (is (= "fiber" (get actual :type)))
  (is (string? (get actual :value)))
  (is (string/has-prefix? "<fiber" (get actual :value))))

(deftest cfunction-conversion
  (def actual (util/to-inspectable print))
  (is (= "cfunction" (get actual :type)))
  (is (string? (get actual :value)))
  (is (string/has-prefix? "<cfunction" (get actual :value))))

(run-tests!)

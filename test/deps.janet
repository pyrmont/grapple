(use ../deps/testament)

(import ../lib/deps :as deps)

# Tests

(deftest deps-clear-graph-function
  # Test the clear-graph function itself
  (def graph (deps/make-dep-graph))
  # Track some definitions
  (def source1 '(def foo 10))
  (def source2 '(def bar (+ foo 5)))
  (def source3 '(defn baz [] (* bar 2)))
  (deps/track-definition graph source1 nil nil nil)
  (deps/track-definition graph source2 nil nil nil)
  (deps/track-definition graph source3 nil nil nil)
  # Verify graph has entries
  (is (> (length (graph :deps)) 0))
  (is (> (length (graph :sources)) 0))
  # Clear the graph
  (deps/clear-graph graph)
  # Verify graph is empty
  (is (= 0 (length (graph :deps))))
  (is (= 0 (length (graph :dependents))))
  (is (= 0 (length (graph :sources)))))

(deftest deps-line-number-ordering
  # Test that bindings with equal dependency counts are sorted by line number
  (def graph (deps/make-dep-graph))

  # Create a parser and parse code with multiple bindings on different lines
  (def p (parser/new))
  (parser/consume p "(def x 10)\n(def a (+ x 1))\n(def b (+ x 2))\n(def c (+ x 3))\n")

  # Create a minimal session for the test
  (def sess @{:dep-graph @{"test-file.janet" graph}})

  # Track all definitions
  (while (parser/has-more p)
    (def form (parser/produce p))
    (deps/track-definition graph form nil "test-file.janet" sess))

  # Get reevaluation order - should be sorted by line number
  (def order (deps/get-reeval-order "test-file.janet" 'x sess))

  # Verify order is by line number: a (line 2), b (line 3), c (line 4)
  (is (= 3 (length order)))
  (is (= 'a (get order 0)) "First symbol should be 'a' (line 2)")
  (is (= 'b (get order 1)) "Second symbol should be 'b' (line 3)")
  (is (= 'c (get order 2)) "Third symbol should be 'c' (line 4)"))

(run-tests!)

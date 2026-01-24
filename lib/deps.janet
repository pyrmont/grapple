# Special forms that are built into Janet's compiler
(def- special-forms
  '{def true
    var true
    fn true
    do true
    quote true
    if true
    splice true
    while true
    break true
    set true
    quasiquote true
    unquote true
    upscope true})

(defn- symbol-name [pattern]
  (case (type pattern)
    :symbol [pattern]
    :tuple (mapcat symbol-name pattern)
    :array (mapcat symbol-name pattern)
    :struct (mapcat symbol-name (values pattern))
    []))

(defn- macro-expand1 [x]
  # handle tables
  (defn dotable [t on-value]
    (def newt @{})
    (var key (next t nil))
    (while (not= nil key)
      (def newk (macro-expand1 key))
      (put newt (if (deep= key newk) key newk) (on-value (in t key)))
      (set key (next t key)))
    newt)
  # expand bindings
  (defn expand-bindings [x]
    (case (type x)
      :array (map expand-bindings x)
      :tuple (tuple/slice (map expand-bindings x))
      :table (dotable x expand-bindings)
      :struct (table/to-struct (dotable x expand-bindings))
      (macro-expand1 x)))
  # expand defs
  (defn expanddef [t]
    (def last (in t (- (length t) 1)))
    (def bound (in t 1))
    (tuple/slice
      (array/concat
        @[(in t 0) (expand-bindings bound)]
        (tuple/slice t 2 -2)
        @[(macro-expand1 last)])))
  # expand all
  (defn expandall [t]
    (def args (map macro-expand1 (tuple/slice t 1)))
    (tuple (in t 0) ;args))
  # expand functions
  (defn expandfn [t]
    (def t1 (in t 1))
    (if (symbol? t1)
      (do
        (def args (map macro-expand1 (tuple/slice t 3)))
        (tuple 'fn t1 (in t 2) ;args))
      (do
        (def args (map macro-expand1 (tuple/slice t 2)))
        (tuple 'fn t1 ;args))))
  # expand quasi-quotes
  (defn expandqq [t]
    (defn qq [x]
      (case (type x)
        :tuple (if (= :brackets (tuple/type x))
                 ~[,;(map qq x)]
                 (do
                   (def x0 (get x 0))
                   (if (= 'unquote x0)
                     (tuple x0 (macro-expand1(get x 1)))
                     (tuple/slice (map qq x)))))
        :array (map qq x)
        :table (table ;(map qq (kvs x)))
        :struct (struct ;(map qq (kvs x)))
        x))
    (tuple (in t 0) (qq (in t 1))))
  # specials
  (def specs
    {'set expanddef
     'def expanddef
     'do expandall
     'fn expandfn
     'if expandall
     'quote identity
     'quasiquote expandqq
     'var expanddef
     'while expandall
     'break expandall
     'upscope expandall})
  # handle tuples
  (defn dotup [t]
    (if (= nil (next t)) (break ()))
    (def h (in t 0))
    (def s (in specs h))
    (def entry (or (dyn h) {}))
    (def m (do (def r (get entry :ref)) (if r (in r 0) (get entry :value))))
    (def m? (in entry :macro))
    (cond
      s (keep-syntax t (s t))
      m? (do (setdyn *macro-form* t) (m ;(tuple/slice t 1)))
      (keep-syntax! t (map macro-expand1 t))))
  # setup return
  (def ret
    (case (type x)
      :tuple (if (= (tuple/type x) :brackets)
               (tuple/brackets ;(map macro-expand1 x))
               (dotup x))
      :array (map macro-expand1 x)
      :struct (table/to-struct (dotable x macro-expand1))
      :table (dotable x macro-expand1)
      x))
  ret)

(defn- macro-expand [x]
  (var previous x)
  (var current (macro-expand1 x))
  (var counter 0)
  (while (deep-not= current previous)
    (if (> (++ counter) 200)
      (error "macro expansion too nested"))
    (set previous current)
    (set current (macro-expand1 current)))
  current)

(defn- walk-params [params]
  (def names @{})
  (each param params
    (cond
      # special markers like & &opt &keys &named
      (and (symbol? param) (string/has-prefix? "&" param))
      nil
      # regular parameter
      (symbol? param)
      (put names param true)
      # destructuring
      (or (tuple? param) (array? param) (struct? param))
      (each sym (symbol-name param)
        (put names sym true))))
  names)

(defn- extract-deps [form &opt initial-locals is-macro?]
  (default initial-locals {})
  (default is-macro? false)
  # first expand all macros
  (def expanded (macro-expand form))
  # collect all def/var/fn bindings in the expanded form (these are local to this expression)
  (def local-bindings (merge initial-locals))
  (defn collect-bindings [x]
    (when (tuple? x)
      (def head (get x 0))
      (cond
        # handle def/var bindings
        (or (= head 'def) (= head 'var))
        (do
          (def pattern (get x 1))
          (each sym (symbol-name pattern)
            (put local-bindings sym true)))
        # handle fn, parameters are local bindings
        (= head 'fn)
        (do
          # check if named function (fn name [params] ...) or anonymous (fn [params] ...)
          (def second (get x 1))
          (def is-named (or (symbol? second) (keyword? second)))
          (def params (if is-named (get x 2) second))
          # add function name to locals if named
          (when is-named
            (put local-bindings second true))
          # add parameters to locals
          (when (or (tuple? params) (array? params))
            (eachk sym (walk-params params)
              (put local-bindings sym true)))))
      # recursively collect from nested forms
      (each item x (collect-bindings item))))
  (collect-bindings expanded)
  # now collect all symbol references that aren't local or in root-env
  (def deps @{})
  (var collect-deps nil)
  (var collect-from-qq nil)
  # Helper to collect deps from within quasiquoted forms
  (set collect-from-qq
    (fn [form]
      (case (type form)
        :symbol
        # for macros, symbols in quasiquotes (even without unquote) are dependencies
        # because they'll be evaluated in the calling context
        (when is-macro?
          (unless (or (in local-bindings form)
                      (in root-env form)
                      (in special-forms form))
            (put deps form true)))
        :tuple
        (let [h (get form 0)]
          (if (= h 'unquote)
            # unquoted expression - collect deps normally
            (collect-deps (get form 1))
            # not unquoted - recurse to find nested unquotes/symbols
            (each item form (collect-from-qq item))))
        :array
        (each item form (collect-from-qq item))
        :struct
        (eachp [k v] form (collect-from-qq k) (collect-from-qq v))
        :table
        (eachp [k v] form (collect-from-qq k) (collect-from-qq v)))))
  (set collect-deps
    (fn [x]
      (case (type x)
        :symbol
        (let [sym x]
          (unless (or (in local-bindings sym)
                      (in root-env sym)
                      (in special-forms sym))
            (put deps sym true)))
        :tuple
        (let [head (get x 0)]
          (cond
            # quoted forms have no dependencies
            (= head 'quote)
            nil
            # quasiquoted forms only depend on unquoted expressions
            (= head 'quasiquote)
            (collect-from-qq (get x 1))
            # normal tuple - collect from all items
            (each item x (collect-deps item))))
        :array
        (each item x (collect-deps item))
        :struct
        (eachp [k v] x (collect-deps k) (collect-deps v))
        :table
        (eachp [k v] x (collect-deps k) (collect-deps v)))))
  (collect-deps expanded)
  (keys deps))

(defn- find-trans-depnts [graph sym &opt visited]
  (default visited @{})
  # avoid cycles
  (when (in visited sym)
    (break @[]))
  (put visited sym true)
  (def direct-deps (get-in graph [:dependents sym] @[]))
  (def all-deps @[])
  (each dep direct-deps
    # Don't include a symbol that's already been visited (prevents cycles and self-reference)
    (unless (in visited dep)
      (array/push all-deps dep)
      (array/concat all-deps (find-trans-depnts graph dep visited))))
  all-deps)

(defn- kahn-sort [nodes deps-fn depnts-fn sess]
  (defn key-fn [[path sym]]
    (string path ":" sym))
  (defn comp-fn [[p1 s1] [p2 s2]]
    (if (= p1 p2)
      (do
        (def graph (get-in sess [:dep-graph p1]))
        (< (get-in graph [:sources s1 :line] math/inf)
           (get-in graph [:sources s2 :line] math/inf)))
      (< p1 p2)))
  # Build set for quick lookup
  (def node-set @{})
  (each node nodes
    (put node-set (key-fn node) node))
  # Count how many dependencies of each node are also in the affected set
  (def pending @{})
  (each node nodes
    (def key (key-fn node))
    (def deps (deps-fn node))
    (def affected-deps (filter (fn [dep] (in node-set (key-fn dep))) deps))
    (put pending key (length affected-deps)))
  # Find all nodes with no pending dependencies
  (def ready @[])
  (each node nodes
    (def key (key-fn node))
    (when (= (get pending key) 0)
      (array/push ready node)))
  (sort ready comp-fn)
  # Process nodes using index-based FIFO queue
  (def result @[])
  (var queue-idx 0)
  (while (< queue-idx (length ready))
    (def node (in ready queue-idx))
    (++ queue-idx)
    (def key (key-fn node))
    (array/push result node)
    # Collect newly ready nodes
    (def newly-ready @[])
    # Decrement pending for dependents
    (def dependents (depnts-fn node))
    (each dep dependents
      (def dep-key (key-fn dep))
      (when (in node-set dep-key)
        (def new-count (- (get pending dep-key) 1))
        (put pending dep-key new-count)
        (when (= new-count 0)
          (array/push newly-ready dep))))
    # Add newly ready nodes in sorted order
    (unless (empty? newly-ready)
      (sort newly-ready comp-fn)
      (array/concat ready newly-ready)))
  # Check for cycles
  (when (not= (length result) (length nodes))
    (def unprocessed (filter (fn [node] (> (get pending (key-fn node)) 0)) nodes))
    (def msg (string "cross-file dependency cycle detected: "
                     (string/join (map (fn [[p s]] (string p ":" s)) unprocessed) ", ")))
    (error msg))
  result)

# Dependency graph management

(defn clear-graph
  [graph &named keep-imports?]
  (put graph :deps @{})
  (put graph :dependents @{})
  (put graph :sources @{})
  (unless keep-imports?
    (put graph :importers @{})))

(defn extract-pattern-symbols
  [pattern]
  (def symbols @[])
  (defn walk [p]
    (cond
      (symbol? p) (array/push symbols p)
      (tuple? p) (each item p (walk item))
      (array? p) (each item p (walk item))
      (struct? p) (eachp [k v] p (walk v))
      (table? p) (eachp [k v] p (walk v))))
  (walk pattern)
  symbols)

(defn topological-sort
  ```
  Sorts symbols topologically across multiple files using Kahn's algorithm.

  Takes an array of [path sym] pairs and a session object, returns them in
  dependency order (dependencies before dependents), sorted alphabetically
  by file path and line number for stable ordering.
  ```
  [affected sess]
  # Helper to get line number for a symbol
  (defn get-line [path sym]
    (def graph (get-in sess [:dep-graph path]))
    (get-in graph [:sources sym :line] math/inf))
  # Helper to get all dependencies of a [path sym] node
  (defn get-deps [[path sym]]
    (def graph (get-in sess [:dep-graph path]))
    (def local-deps (get-in graph [:deps sym] @[]))
    (def all-deps @[])
    # Add local dependencies (same file)
    (each dep local-deps
      (array/push all-deps [path dep]))
    # Add cross-file dependencies
    (def env (module/cache path))
    (when env
      (each dep local-deps
        (def binding (get env dep))
        (when binding
          (def source-map (get binding :source-map))
          # If source is from another file, track it
          (when (and (tuple? source-map) (not= (get source-map 0) path))
            (def dep-path (get source-map 0))
            (def source-env (module/cache dep-path))
            (when source-env
              # Find the original symbol in the source file
              (eachp [source-sym source-binding] source-env
                (when (= (get source-binding :source-map) source-map)
                  (array/push all-deps [dep-path source-sym])
                  (break))))))))
    all-deps)
  # Helper to get all dependents of a [path sym] node
  (defn get-depnts [[path sym]]
    (def graph (get-in sess [:dep-graph path]))
    (def all-deps @[])
    # Add local dependents (same file)
    (def local-depnts (get-in graph [:dependents sym] @[]))
    (each dep local-depnts
      (array/push all-deps [path dep]))
    # Add cross-file dependents
    (def importers (get-in graph [:importers sym] @[]))
    (each {:file other-path :as imported-sym} importers
      (def other-graph (get-in sess [:dep-graph other-path]))
      (when other-graph
        (def other-depnts (get-in other-graph [:dependents imported-sym] @[]))
        (each other-dep other-depnts
          (array/push all-deps [other-path other-dep]))))
    all-deps)
  (kahn-sort affected get-deps get-depnts sess))

(defn collect-affected-nodes
  ```
  Collects all nodes (local and cross-file) that need re-evaluation when a symbol changes.

  Uses BFS to traverse both local dependents and cross-file dependents (via importers).
  Returns an array of [path sym] pairs representing all affected nodes.
  ```
  [initial-path initial-sym sess]
  (def affected @[])
  (def visited @{})
  (def queue @[[initial-path initial-sym]])
  (defn key-fn [[p s]] (string p ":" s))
  (while (not (empty? queue))
    (def [path sym] (array/pop queue))
    (def key (key-fn [path sym]))
    # Skip if already visited
    (unless (in visited key)
      (put visited key true)
      (def graph (get-in sess [:dep-graph path]))
      (when graph
        # Add local dependents
        (def local-depnts (get-in graph [:dependents sym] @[]))
        (each dep local-depnts
          (def dep-key (key-fn [path dep]))
          (unless (in visited dep-key)
            (array/push affected [path dep])
            (array/push queue [path dep])))
        # Add cross-file dependents via importers
        (def importers (get-in graph [:importers sym] @[]))
        (each {:file other-path :as imported-sym} importers
          (def other-graph (get-in sess [:dep-graph other-path]))
          (when other-graph
            (def other-depnts (get-in other-graph [:dependents imported-sym] @[]))
            (each other-dep other-depnts
              (def other-key (key-fn [other-path other-dep]))
              (unless (in visited other-key)
                (array/push affected [other-path other-dep])
                (array/push queue [other-path other-dep]))))))))
  affected)

(defn get-reeval-order
  ```
  Gets the list of symbols to re-evaluate when sym is redefined, in order.

  Takes path, sym, and sess to use unified topological sorting.
  ```
  [path sym sess]
  (def graph (get-in sess [:dep-graph path]))
  (unless graph
    (break @[]))
  # find all trans dependents
  (def all-depnts (find-trans-depnts graph sym))
  (when (empty? all-depnts)
    (break @[]))
  # remove duplicates and convert to [path sym] pairs
  (def unique-deps (distinct all-depnts))
  (def node-pairs (map (fn [s] [path s]) unique-deps))
  # use unified topological sort
  (def sorted-pairs (topological-sort node-pairs sess))
  # extract just the symbols
  (map (fn [[p s]] s) sorted-pairs))

(defn make-dep-graph
  []
  @{:deps @{}        # sym -> [dependencies]
    :dependents @{}  # sym -> [symbols that depend on this]
    :sources @{}     # sym -> {:form source :line num :col num}
    :importers @{}}) # sym -> [{:file path :as imported-sym}]

(defn track-definition
  [graph source env path sess]
  # no source value so return early
  (unless (and (tuple? source) (> (length source) 1))
    (break))
  (def head (in source 0))
  # no binding creation so return early
  # TODO: Does this need to also handle `set`?
  (unless (or (= head 'def) (= head 'var) (= head 'defn) (= head 'defmacro))
    (break))
  (def pattern (in source 1))
  # handle both simple symbols and destructuring patterns
  (def syms (if (symbol? pattern)
              [pattern]
              # for def/var with patterns, extract all symbols
              (if (or (= head 'def) (= head 'var))
                (extract-pattern-symbols pattern)
                [])))
  # no symbols so return early
  (when (empty? syms)
    (break))
  # extract dependencies from the value expression
  (def value-expr (if (or (= head 'defn) (= head 'defmacro))
                    # for defn/defmacro, analyze the function body
                    (tuple 'fn ;(slice source 2))
                    # for def/var, analyze the value
                    (in source 2)))
  (def dep-list (extract-deps value-expr {} (= head 'defmacro)))
  # for each symbol in the pattern, track dependencies
  (each sym syms
    # store dependencies: sym -> [dependencies]
    (put-in graph [:deps sym] dep-list)
    # store source with line/column metadata for re-evaluation
    (def [line col] (or (tuple/sourcemap source) [nil nil]))
    (put-in graph [:sources sym] {:form source :line line :col col})
    # update reverse index and check for cross-file dependencies
    (each dep dep-list
      # update reverse index: for each dependency, add sym to its dependents
      # but don't add a symbol to its own dependents list
      (unless (= sym dep)
        (def dependents (get-in graph [:dependents dep] @[]))
        (unless (find (partial = sym) dependents)
          (array/push dependents sym))
        (put-in graph [:dependents dep] dependents))
      # look up the dependency in the environment
      (when (def binding (get env dep))
        # check if it has a source map from a different file
        (def source-map (get binding :source-map))
        (assert (tuple? source-map) "need source maps enabled")
        (def dep-path (get source-map 0))
        # if source file differs from current file, it's a cross-file dependency
        (unless (= dep-path path)
          (when-let [source-graph (get-in sess [:dep-graph dep-path])
                     source-env (module/cache dep-path)]
            (eachp [source-sym source-binding] source-env
              (when (= (get source-binding :source-map) source-map)
                (def importers (get (source-graph :importers) source-sym @[]))
                (def import-info {:file path :as dep})
                (unless (find (fn [x] (and (= path (x :file)) (= dep (x :as)))) importers)
                  (array/push importers import-info))
                (put-in source-graph [:importers source-sym] importers)
                (break)))))))))

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

(defn- symbol-name
  "Extract symbol name, handling destructuring patterns"
  [pattern]
  (case (type pattern)
    :symbol [pattern]
    :tuple (mapcat symbol-name pattern)
    :array (mapcat symbol-name pattern)
    :struct (mapcat symbol-name (values pattern))
    []))

(defn macro-expand1
  "Expand macros (reimplementation of macex1)"
  [x]
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

(defn- macro-expand
  [x]
  (var previous x)
  (var current (macro-expand1 x))
  (var counter 0)
  (while (deep-not= current previous)
    (if (> (++ counter) 200)
      (error "macro expansion too nested"))
    (set previous current)
    (set current (macro-expand1 current)))
  current)

(defn- walk-params
  "Extract parameter names from function parameter list"
  [params]
  (def names @{})
  (each param params
    (cond
      # Special markers like & &opt &keys &named
      (and (symbol? param) (string/has-prefix? "&" param))
      nil
      # Regular parameter
      (symbol? param)
      (put names param true)
      # Destructuring
      (or (tuple? param) (array? param) (struct? param))
      (each sym (symbol-name param)
        (put names sym true))))
  names)

# (defn- walk-let-bindings
#   "Extract local names from let bindings"
#   [bindings]
#   (def names @{})
#   (var i 0)
#   (while (< i (length bindings))
#     (def pattern (get bindings i))
#     (each sym (symbol-name pattern)
#       (put names sym true))
#     (+= i 2))
#   names)

(defn- extract-deps
  "Extract dependencies using macex - expands all macros first, then analyzes.
  This handles all binding forms automatically without manual case handling."
  [form &opt initial-locals]
  (default initial-locals {})
  # First expand all macros
  (def expanded (macro-expand form))
  # Collect all def/var/fn bindings in the expanded form (these are local to this expression)
  (def local-bindings (merge initial-locals))
  (defn collect-bindings [x]
    (when (tuple? x)
      (def head (get x 0))
      (cond
        # Handle def/var bindings
        (or (= head 'def) (= head 'var))
        (do
          (def pattern (get x 1))
          (each sym (symbol-name pattern)
            (put local-bindings sym true)))
        # Handle fn - parameters are local bindings
        (= head 'fn)
        (do
          # Check if named function (fn name [params] ...) or anonymous (fn [params] ...)
          (def second (get x 1))
          (def is-named (symbol? second))
          (def params (if is-named (get x 2) second))
          # Add function name to locals if named
          (when is-named
            (put local-bindings second true))
          # Add parameters to locals
          (when (or (tuple? params) (array? params))
            (eachk sym (walk-params params)
              (put local-bindings sym true)))))
      # Recursively collect from nested forms
      (each item x (collect-bindings item))))
  (collect-bindings expanded)
  # Now collect all symbol references that aren't local or in root-env
  (def deps @{})
  (defn collect-deps [x]
    (case (type x)
      :symbol
      (let [sym x]
        (unless (or (in local-bindings sym)
                    (in root-env sym)
                    (in special-forms sym))
          (put deps sym true)))
      :tuple
      (each item x (collect-deps item))
      :array
      (each item x (collect-deps item))
      :struct # TODO: Do you need to do this for k?
      (eachp [k v] x (collect-deps k) (collect-deps v))
      :table # TODO: Do you need to do this for k?
      (eachp [k v] x (collect-deps k) (collect-deps v))))
  (collect-deps expanded)
  (keys deps))

# Dependency graph management

(defn make-dep-graph
  "Create a new dependency graph"
  []
  @{:deps @{}        # sym -> [dependencies]
    :dependents @{}  # sym -> [symbols that depend on this]
    :sources @{}})   # sym -> source form for re-evaluation

(defn extract-pattern-symbols
  "Extract all symbols from a destructuring pattern"
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

(defn track-definition
  "Track dependencies for a definition form and update the graph"
  [graph source]
  (when (and (tuple? source) (> (length source) 1))
    (def head (in source 0))
    (when (or (= head 'def) (= head 'var) (= head 'defn) (= head 'defmacro))
      (def pattern (in source 1))
      # Handle both simple symbols and destructuring patterns
      (def syms (if (symbol? pattern)
                  [pattern]
                  # For def/var with patterns, extract all symbols
                  (if (or (= head 'def) (= head 'var))
                    (extract-pattern-symbols pattern)
                    [])))
      (unless (empty? syms)
        # Extract dependencies from the value expression
        (def value-expr (if (or (= head 'defn) (= head 'defmacro))
                          # For defn/defmacro, analyze the function body
                          (tuple 'fn ;(slice source 2))
                          # For def/var, analyze the value
                          (in source 2)))
        (def dep-list (extract-deps value-expr))
        # For each symbol in the pattern, track dependencies
        (each sym syms
          # Store dependencies: sym -> [dependencies]
          (put (graph :deps) sym dep-list)
          # Store source for re-evaluation
          (put (graph :sources) sym source)
          # Update reverse index: for each dependency, add sym to its dependents
          (each dep dep-list
            (def dependents (or (get (graph :dependents) dep) @[]))
            (unless (find (partial = sym) dependents)
              (array/push dependents sym))
            (put (graph :dependents) dep dependents)))
        # Return the first symbol that was defined
        (get syms 0)))))

(defn find-transitive-dependents
  "Find all symbols that transitively depend on sym"
  [graph sym &opt visited]
  (default visited @{})
  # Avoid cycles
  (when (in visited sym)
    (break @[]))
  (put visited sym true)
  (def direct-deps (or (get-in graph [:dependents sym]) @[]))
  (def all-deps @[])
  (each dep direct-deps
    (array/push all-deps dep)
    (array/concat all-deps (find-transitive-dependents graph dep visited)))
  all-deps)

(defn topological-sort
  "Sort symbols in dependency order (dependencies before dependents)"
  [graph syms]
  (def sym-set @{})
  (each s syms (put sym-set s true))
  # Count dependencies within the set for each symbol
  (defn dep-count [sym]
    (def deps (or (get-in graph [:deps sym]) @[]))
    (length (filter (partial in sym-set) deps)))
  # Sort by dependency count (symbols with fewer deps first)
  (sorted syms (fn [a b] (< (dep-count a) (dep-count b)))))

(defn get-reevaluation-order
  "Get the list of symbols to re-evaluate when sym is redefined, in order"
  [graph sym]
  # Find all transitive dependents
  (def all-dependents (find-transitive-dependents graph sym))
  (when (empty? all-dependents)
    (break @[]))
  # Remove duplicates and sort in dependency order
  (def unique-deps (distinct all-dependents))
  (topological-sort graph unique-deps))

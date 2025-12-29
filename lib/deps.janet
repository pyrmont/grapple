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

(defn- extract-deps [form &opt initial-locals]
  (default initial-locals {})
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

(defn- find-transitive-dependents [graph sym &opt visited]
  (default visited @{})
  # avoid cycles
  (when (in visited sym)
    (break @[]))
  (put visited sym true)
  (def direct-deps (get-in graph [:dependents sym] @[]))
  (def all-deps @[])
  (each dep direct-deps
    (array/push all-deps dep)
    (array/concat all-deps (find-transitive-dependents graph dep visited)))
  all-deps)

(defn- topological-sort [graph syms]
  (def sym-set @{})
  (each s syms (put sym-set s true))
  # count dependencies within the set for each symbol
  (defn dep-count [sym]
    (def deps (get-in graph [:deps sym] @[]))
    (length (filter (partial in sym-set) deps)))
  # get line number for a symbol, defaulting to infinity if unavailable
  (defn line-number [sym]
    (get-in graph [:sources sym :line] math/inf))
  # sort by dependency count first, then by line number
  (sorted syms (fn [a b]
                 (def count-a (dep-count a))
                 (def count-b (dep-count b))
                 (if (= count-a count-b)
                   # secondary sort: by line number
                   (< (line-number a) (line-number b))
                   # primary sort: by dependency count
                   (< count-a count-b)))))

# Dependency graph management

(defn clear-graph
  "Clears all entries in a dependency graph, resetting it to empty state"
  [graph &named keep-imports?]
  (put graph :deps @{})
  (put graph :dependents @{})
  (put graph :sources @{})
  (unless keep-imports?
    (put graph :importers @{})))

(defn extract-pattern-symbols
  "Extracts all symbols from a destructuring pattern"
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

(defn get-reeval-order
  "Gets the list of symbols to re-evaluate when sym is redefined, in order"
  [graph sym]
  # find all transitive dependents
  (def all-dependents (find-transitive-dependents graph sym))
  (when (empty? all-dependents)
    (break @[]))
  # remove duplicates and sort in dependency order
  (def unique-deps (distinct all-dependents))
  (topological-sort graph unique-deps))

(defn make-dep-graph
  "Creates a new dependency graph"
  []
  @{:deps @{}        # sym -> [dependencies]
    :dependents @{}  # sym -> [symbols that depend on this]
    :sources @{}     # sym -> {:form source :line num :col num}
    :importers @{}}) # sym -> [{:file path :as imported-sym}]

(defn track-definition
  "Tracks dependencies for a definition form and updates the graph"
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
  (def dep-list (extract-deps value-expr))
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
      (def dependents (get-in graph [:dependents dep] @[]))
      (unless (find (partial = sym) dependents)
        (array/push dependents sym))
      (put-in graph [:dependents dep] dependents)
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

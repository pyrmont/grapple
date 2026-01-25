(import ./utilities :as util)
(import ./deps :as deps)

(def- debugger-env
  (require "./debugger"))

(defn- dprint [v]
  (xprintf stdout "%q" v))

(def- eval-root-env
  (do
    (defn rebind [env sym new-val]
      (def bndg (table/clone (env sym)))
      (put bndg :value new-val)
      (put env sym bndg))
    (def new-env (table/clone root-env))
    (defn new-make-env [&opt parent]
      (default parent new-env)
      (table/setproto @{} parent))
    (defn new-curenv [&opt n]
      (curenv (if (dyn :grapple/eval-env?) 1)))
    (defmacro new-import [path & args]
      (def ps (partition 2 args))
      (def argm (mapcat (fn [[k v]] [k (case k :as (string v) :only ~(quote ,v) v)]) ps))
      (tuple 'import* (string path) ;argm))
    (defn new-import* [path & args]
      (def env (table/getproto (curenv)))
      (def kargs (table ;args))
      (def {:as as
            :prefix prefix
            :export ep
            :only only} kargs)
      (defn extract-binds [reqenv]
        (if (reqenv :grapple/eval-env?)
          (do
            (def parent (table/getproto reqenv))
            (each sym (all-bindings reqenv true)
              (put parent sym (reqenv sym)))
            parent)
          reqenv))
      (def newenv (extract-binds (require path ;args)))
      (def prefix (or
                    (and as (string as "/"))
                    prefix
                    (string (last (string/split "/" path)) "/")))
      (merge-module env newenv prefix ep only))
    (defmacro new-use [& modules]
      ~(do ,;(map |~(,import* ,(string $) :prefix "") modules)))
    (rebind new-env 'root-env new-env)
    (rebind new-env 'make-env new-make-env)
    (rebind new-env 'curenv new-curenv)
    (rebind new-env 'import* new-import*)
    (rebind new-env 'import new-import)
    (rebind new-env 'use new-use)
    (rebind new-env 'stdout (fn [& args] (xprin (dyn :out) ;args)))
    (rebind new-env 'stderr (fn [& args] (xprin (dyn :err) ;args)))
    (put new-env :redef false)
    (put new-env :debug true)
    (put new-env :module-make-env new-make-env)
    (put new-env :out (fn :out [x] (error "tried to output")))
    (put new-env :err (fn :err [x] (error "tried to output")))
    new-env))

(defn- find-breakpoints [sess path sym]
  (def bp-ids @[])
  (def breakpoints (get sess :breakpoints @[]))
  (eachk i breakpoints
    (def bp-info (get breakpoints i))
    (when (and bp-info
               (= (get bp-info :path) path)
               (= (get bp-info :binding) sym))
      (array/push bp-ids i)))
  bp-ids)

(defn- bad-compile [send-err]
  (fn :bad-compile [msg macrof where &opt line col]
    (def full-msg
      (string "compile error: "
              (if macrof (string (fiber/status macrof) ": "))
              msg))
    (def details {"janet/path" where
                  "janet/line" line
                  "janet/col" col
                  "janet/stack" (if macrof (util/stack macrof))})
    (send-err full-msg details)))

(defn- bad-parse [send-err]
  (fn :bad-parse [p where]
    (def [line col] (parser/where p))
    (def full-msg (string "parse error: " (parser/error p)))
    (def details {"janet/path" where
                  "janet/line" line
                  "janet/col" col})
    (send-err full-msg details)))

(defn- debugger-on-status [env level opts]
  # This function is called within the evaluator after resuming the evaluator
  # fiber. It is named :debugger because this function is what makes it possible
  # to perform remote debugging.
  (fn :debugger [f x where line col]
    (case (fiber/status f)
      :dead
      (do
        (put env '_ @{:value x})
        (def send (opts :ret))
        (def reeval? (not (empty? (opts :reevaluating))))
        (send (string/format "%q" x)
              {"done" false
               "janet/path" where
               "janet/line" line
               "janet/col" col
               # Mark as reevaluation if in a cascade
               "janet/reeval?" reeval?
               # Include structured representation for client-side inspection
               "janet/result" (util/to-inspectable x)}))
      :debug
      (do
        (def stack (debug/stack f))
        (def frame (first stack))
        (def func (frame :function))
        (def send-sig (opts :sig))
        (send-sig "debug" (util/debug-payload f :debug))
        (var action (debug)) # yields to handler
        (forever
          (set action
            (case action
              :continue (break)
              :step (do
                      (debug/step f)
                      (if (= :debug (fiber/status f))
                        (debug)  # yield again, still debugging
                        (break))) # done stepping, continue execution
              :fiber (debug f)
              :stack (debug (debug/stack f))
              # default - unknown command
              (debug nil)))))
      # errors
      (do
        (def send (opts :err))
        (send (string (fiber/status f) ": " x)
              {"janet/path" where
               "janet/line" line
               "janet/col" col
               "janet/stack" (util/stack f)})))))

(defn- warn-compile [send-note]
  (fn :warn-compile [msg level where &opt line col]
    (def full-msg (string "compile warning (" level "): " msg))
    (def details {"janet/path" where
                  "janet/line" line
                  "janet/col" col})
    (send-note full-msg details)))

# Public functions

(defn eval-make-env [&opt parent]
  (default parent eval-root-env)
  (def env (make-env parent)))

# based on run-context
(defn run [code &named env parser path req send sess]
  (unless (and env req send sess)
    (error "missing :env, :req, :send and :sess parameters"))
  (default path util/ns)
  (def cmd (util/make-send-cmd req send))
  (def err (util/make-send-err req send))
  (def note (util/make-send-note req send))
  (def out-1 (util/make-send-out req send "out"))
  (def out-2 (util/make-send-out req send "err"))
  (def ret (util/make-send-ret req send))
  (def sig (util/make-send-sig req send))
  (defn module-make-env [&opt parent no-wrap?]
    (default parent eval-root-env)
    (def new-env (if no-wrap? parent (table/setproto @{} parent)))
    (def new-eval-env @{:out out-1
                        :err out-2
                        :module-make-env module-make-env
                        :grapple/eval-env? true})
    (table/setproto new-eval-env new-env))
  (def eval1-env (module-make-env env true))
  (def reevaluating @{})
  (def opts {:err err
             :ret ret
             :sig sig
             :reevaluating reevaluating})
  (def on-status (debugger-on-status env 1 opts))
  (def on-compile-error (bad-compile err))
  (def on-compile-warning (warn-compile note))
  (def on-parse-error (bad-parse err))
  (def evaluator (fn evaluate [x &] (x)))
  (def where (or path util/ns))
  (def p (or parser (parser/new)))
  (def guard :ydt)
  # set current file
  (put eval1-env :current-file where)
  # normally located outside run-context body
  (def lint-levels
    {:none 0
     :relaxed 1
     :normal 2
     :strict 3
     :all math/inf})
  # dependency tracking
  (defn- get-dep-graph [path]
    (or (get-in sess [:dep-graph path])
        (let [g (deps/make-dep-graph)]
          (unless (get sess :dep-graph)
            (put sess :dep-graph @{}))
          (put-in sess [:dep-graph path] g)
          g)))
  # forward declaration for mutual recursion
  (var eval1 nil)
  (def lints @[])
  # helper to compile and evaluate source in a fiber
  (defn compile-and-eval [source env eval-env path &opt l c]
    (var good true)
    (var resumeval nil)
    (def f
      (fiber/new
        (fn []
          (array/clear lints)
          (def res (compile source env path lints))
          (unless (empty? lints)
            (def levels (get env *lint-levels* lint-levels))
            (def lint-error (get env *lint-error*))
            (def lint-warning (get env *lint-warn*))
            (def lint-error (or (get levels lint-error lint-error) 0))
            (def lint-warning (or (get levels lint-warning lint-warning) 2))
            (each [level line col msg] lints
              (def lvl (get lint-levels level 0))
              (cond
                (<= lvl lint-error) (do
                                      (set good false)
                                      (on-compile-error msg nil path (or line l) (or col c)))
                (<= lvl lint-warning) (on-compile-warning msg level path (or line l) (or col c)))))
          (when good
            (if (= (type res) :function)
              (evaluator res source env path)
              (do
                (set good false)
                (def {:error err :line line :column column :fiber errf} res)
                (on-compile-error err errf path (or line l) (or column c))))))
        guard
        eval-env))
    (while (fiber/can-resume? f)
      (def res (resume f resumeval))
      (when good
        (set resumeval (on-status f res path l c))))
    good)
  # helper to evaluate source in a different file's environment
  # but with the same fiber context (output, errors, etc.)
  (defn eval-in-file [source target-env target-path &opt l c]
    (def target-eval-env (module-make-env target-env true))
    (put target-eval-env :current-file target-path)
    (compile-and-eval source target-env target-eval-env target-path l c))
  # helper to re-evaluate a symbol with tracking
  (defn reeval-with-tracking [sym f]
    (unless (in reevaluating sym)
      (put reevaluating sym true)
      (f)
      (put reevaluating sym nil)))
  (defn reeval-depents [sym]
    # return early if already reevaluating (nested cascade)
    (unless (empty? reevaluating)
      (break))
    # Get direct local dependents (file-local only, no cross-file)
    (def local-deps (deps/get-reeval-order path sym sess))
    (def local-deps-set @{})
    (each dep local-deps
      (put local-deps-set dep true))
    # Collect all affected nodes (both local and cross-file)
    (def all-affected (deps/collect-affected-nodes path sym sess))
    # If nothing to re-evaluate, return early
    (when (empty? all-affected)
      (break))
    # Topologically sort all affected nodes (unified pass)
    (def ordered (deps/topological-sort all-affected sess))
    # Track which files we've sent notifications for
    (def notified-files @{})
    # Re-evaluate in topological order
    (each [node-path node-sym] ordered
      # Check if this is a direct local dependent (vs circular/cross-file)
      (def is-local? (and (= node-path path) (in local-deps-set node-sym)))
      # Send notification for this file if we haven't yet
      (unless (in notified-files node-path)
        (put notified-files node-path true)
        # Collect all symbols from this file that will be re-evaluated
        (def file-syms (filter (fn [[p s]] (= p node-path)) ordered))
        (def sym-names (map (fn [[p s]] s) file-syms))
        (def dep-names (string/join (map string sym-names) ", "))
        # Check if ALL symbols in this file are local deps
        (def all-local? (and (= node-path path)
                             (all (fn [[p s]] (in local-deps-set s)) file-syms)))
        (if all-local?
          # Local file notification (only if all symbols are direct local deps)
          (note (string "Re-evaluating dependents of " sym ": " dep-names))
          # Cross-file notification (or circular deps)
          (note (string "Re-evaluating in " node-path ": " dep-names))))
      # Get graph and environment for this node
      (def node-graph (get-in sess [:dep-graph node-path]))
      (def node-env (if is-local? env (module/cache node-path)))
      (when (and node-graph node-env)
        # For non-local re-evaluation, update imported bindings
        (unless is-local?
          (each dep (get-in node-graph [:deps node-sym] @[])
            # Check if this dependency is imported from another file
            (when (def binding (get node-env dep))
              (def source-map (get binding :source-map))
              (when (and (tuple? source-map) (not= (get source-map 0) node-path))
                (def dep-path (get source-map 0))
                (when (def dep-env (module/cache dep-path))
                  # Find and update the binding
                  (each source-binding dep-env
                    (when (= (get source-binding :source-map) source-map)
                      (put node-env dep source-binding)
                      (break))))))))
        # Re-evaluate the symbol
        (when (def source (get-in node-graph [:sources node-sym :form]))
          (if is-local?
            # Direct local dep: use eval1 (no need for binding updates or different env)
            (reeval-with-tracking node-sym (fn [] (eval1 source)))
            # Cross-file or circular: use eval-in-file (with binding updates above)
            (reeval-with-tracking node-sym (fn [] (eval-in-file source node-env node-path))))))))
  # evaluate 1 source form in a protected manner
  (set eval1 (fn eval1-impl [source &opt l c]
    # check if this is a redefinition (before tracking the new def)
    (def graph (get-dep-graph path))
    (var redef? false)
    (var defined-sym nil)
    # check if symbol already exists before tracking
    (when (and (tuple? source) (> (length source) 1))
      (def head (in source 0))
      (when (or (= head 'def) (= head 'var) (= head 'defn) (= head 'defmacro))
        (def pattern (in source 1))
        # handle both symbols and patterns
        (if (symbol? pattern)
          (do
            (set defined-sym pattern)
            (set redef? (not (nil? (get-in graph [:sources pattern])))))
          # for patterns, check first symbol (they all share the same source)
          (when (or (= head 'def) (= head 'var))
            (def syms (deps/extract-pattern-symbols pattern))
            (when (not (empty? syms))
              (set defined-sym (get syms 0))
              (set redef? (not (nil? (get-in graph [:sources (get syms 0)])))))))))
    # track the definition
    (deps/track-definition graph source env path sess)
    # compile and evaluate
    (def good (compile-and-eval source env eval1-env where l c))
    (when (and good defined-sym)
      (def bps (find-breakpoints sess path defined-sym))
      (unless (empty? bps)
        (cmd "clear-breakpoints" {"janet/breakpoints" bps}))
      # after successful evaluation, re-evaluate dependents if this was a
      # redefinition but only at the top level (nested calls are already handled
      # by the outer cascade)
      (when (and redef? (empty? reevaluating))
        (reeval-depents defined-sym)))))
  # handle parser error in the correct environment
  (defn parse-err [p where]
    (def f (coro
             (setdyn :err err)
             (on-parse-error p where)))
    (fiber/setenv f eval1-env)
    (resume f))
  (defn prod-and-eval [p]
    (def tup (parser/produce p true))
    (eval1 (in tup 0) ;(tuple/sourcemap tup)))
  # parse and evaluate
  (var pindex 0)
  (def len (length code))
  (if (= len 0) (parser/eof p))
  (while (> len pindex)
    (+= pindex (parser/consume p code pindex))
    (while (parser/has-more p)
      (prod-and-eval p)
      (if (eval1-env :exit) (break)))
    (when (= :error (parser/status p))
      (parse-err p where)
      (if (eval1-env :exit) (break))))
  # check final parser state
  (unless (eval1-env :exit)
    (parser/eof p)
    (while (parser/has-more p)
      (prod-and-eval p)
      (if (eval1-env :exit) (break)))
    (when (= :error (parser/status p))
      (parse-err p where)))
  # TODO: Should this return env as the alternative?
  (in eval1-env :exit-value))

(defn run-debug [code fiber signal &named req send sess]
  (put debugger-env :fiber fiber)
  (put debugger-env :signal signal)
  (run code :env debugger-env :path "<debug>" :req req :send send :sess sess))

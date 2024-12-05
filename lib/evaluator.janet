(import ./utilities :as util)


(defn- dprint [v]
  (xprintf stdout "%q" v))


(defn- rebind [env sym new-val]
  (def bndg (table/clone (env sym)))
  (put bndg :value new-val)
  (put env sym bndg))


(def- eval-root-env
  (do
    (def new-env (table/clone root-env))

    (defn new-make-env [&opt parent]
      (default parent new-env)
      (table/setproto @{} parent))

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
    (rebind new-env 'import* new-import*)
    (rebind new-env 'import new-import)
    (rebind new-env 'use new-use)
    (rebind new-env 'stdout (fn [& args] (xprin (dyn :out) ;args)))
    (rebind new-env 'stderr (fn [& args] (xprin (dyn :err) ;args)))

    (put new-env :module-make-env new-make-env)
    (put new-env :out (fn :out [x] (error "tried to output")))
    (put new-env :err (fn :err [x] (error "tried to output")))
    new-env))


(defn- stack [f]
  (map (fn [fr] {:name (fr :name)
                 :path (fr :source)
                 :line (fr :source-line)
                 :col  (fr :source-column)})
       (debug/stack f)))


(defn- bad-compile [send-err]
  (fn :bad-compile [msg macrof where &opt line col]
    (def full-msg
      (string "compile error: "
              (if macrof (string (fiber/status macrof) ": "))
              msg))
    (def details {"janet/path" where
                  "janet/line" line
                  "janet/col" col
                  "janet/stack" (if macrof (stack macrof))})
    (send-err full-msg details)))


(defn- bad-parse [send-err]
  (fn :bad-parse [p where]
    (def [line col] (parser/where p))
    (def full-msg (string "parse error: " (parser/error p)))
    (def details {"janet/path" where
                  "janet/line" line
                  "janet/col" col})
    (send-err full-msg details)))


(defn- debugger-on-status [env level send-ret send-err]
  (fn :debugger [f x where line col]
    (def fs (fiber/status f))
    (if (= :dead fs)
      (do
        (put env '_ @{:value x})
        (send-ret (string/format "%q" x)
                  {"done" false
                   "janet/path" where
                   "janet/line" line
                   "janet/col" col}))
      (do
        (send-err (string (fiber/status f) ": " x)
                  {"janet/path" where
                   "janet/line" line
                   "janet/col" col
                   "janet/stack" (stack f)})
        # (if (get env :debug) (debugger f level))
        ))))


(defn- warn-compile [send-note]
  (fn :warn-compile [msg level where &opt line col]
    (def full-msg (string "compile warning (" level "): " msg))
    (def details {"janet/path" where
                  "janet/line" line
                  "janet/col" col})
    (send-note full-msg details)))


(defn eval-make-env [&opt parent]
  (default parent eval-root-env)
  (def env (make-env parent)))


# based on run-context
(defn run [code &named env parser path req send]
  (unless (and env req send)
    (error "missing :env, :req and :send parameters"))
  (def err (util/make-send-err req send))
  (def note (util/make-send-note req send))
  (def out-1 (util/make-send-out req send "out"))
  (def out-2 (util/make-send-out req send "err"))
  (def ret (util/make-send-ret req send))

  (defn module-make-env [&opt parent no-wrap?]
    (default parent eval-root-env)
    (def new-env (if no-wrap? parent (table/setproto @{} parent)))
    (def new-eval-env @{:out out-1
                        :err out-2
                        :module-make-env module-make-env
                        :grapple/eval-env? true})
    (table/setproto new-eval-env new-env))

  (def eval1-env (module-make-env env true))

  (def on-status (debugger-on-status env 1 ret err))
  (def on-compile-error (bad-compile err))
  (def on-compile-warning (warn-compile note))
  (def on-parse-error (bad-parse err))
  (def evaluator (fn evaluate [x &] (x)))
  (def where (or path util/ns))
  (def p (or parser (parser/new)))
  (def guard :ydt)

  # normally located outside run-context body
  (def lint-levels
    {:none 0
     :relaxed 1
     :normal 2
     :strict 3
     :all math/inf})

  # Evaluate 1 source form in a protected manner
  (def lints @[])
  (defn eval1 [source &opt l c]
    (var good true)
    (var resumeval nil)
    (def f
      (fiber/new
        (fn []
          (array/clear lints)
          (def res (compile source env where lints))
          (unless (empty? lints)
            # Convert lint levels to numbers.
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
                                      (on-compile-error msg nil where (or line l) (or col c)))
                (<= lvl lint-warning) (on-compile-warning msg level where (or line l) (or col c)))))
          (when good
            (if (= (type res) :function)
              (evaluator res source env where)
              (do
                (set good false)
                (def {:error err :line line :column column :fiber errf} res)
                (on-compile-error err errf where (or line l) (or column c))))))
        guard
        eval1-env))
    (while (fiber/can-resume? f)
      (def res (resume f resumeval))
      (when good
        (set resumeval (on-status f res where l c)))))

  # Handle parser error in the correct environment
  (defn parse-err [p where]
    (def f (coro
             (setdyn :err err)
             (on-parse-error p where)))
    (fiber/setenv f eval1-env)
    (resume f))

  (defn prod-and-eval [p]
    (def tup (parser/produce p true))
    (eval1 (in tup 0) ;(tuple/sourcemap tup)))

  # Parse and evaluate
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

  # Check final parser state
  (unless (eval1-env :exit)
    (parser/eof p)
    (while (parser/has-more p)
      (prod-and-eval p)
      (if (eval1-env :exit) (break)))
    (when (= :error (parser/status p))
      (parse-err p where)))

  # TODO: Should this return env as the alternative?
  (in eval1-env :exit-value))

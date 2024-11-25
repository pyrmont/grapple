(import ./utilities :as util)


(defn bad-compile [send-err]
  (fn :bad-compile [msg macrof where &opt line col]
    (def full-msg (string "compile error: " msg))
    (def details {"done" false
                  "janet/path" where
                  "janet/line" line
                  "janet/col" col})
    (send-err full-msg details)))


(defn warn-compile [send-err]
  )


(defn bad-parse [send-err]
  (fn :bad-parse [p where]
    (def [line col] (parser/where p))
    (def full-msg (string "parse error: " (parser/error p)))
    (def details {"done" false
                  "janet/path" where
                  "janet/line" line
                  "janet/col" col})
    (send-err full-msg details)))


# based on run-context
(defn run [code &named env path ret out-1 out-2 err]
  (def on-status debug/stacktrace)
  (def on-compile-error bad-compile)
  (def on-compile-warning warn-compile)
  (def on-parse-error (bad-parse err))
  (def evaluator (fn evaluate [x &] (x)))
  (def where (or path :<mrepl>))
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
          (setdyn :out out-1)
          (setdyn :err out-2)
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
        env))
    (while (fiber/can-resume? f)
      (def res (resume f resumeval))
      (when good
        (ret (util/literalise res) {"done" false})
        (set resumeval (on-status f res)))))

  # Handle parser error in the correct environment
  (defn parse-err [p where]
    (def f (coro
             (setdyn :err err)
             (on-parse-error p where)))
    (fiber/setenv f env)
    (resume f))

  (defn prod-and-eval [p]
    (def tup (parser/produce p true))
    (eval1 (in tup 0) ;(tuple/sourcemap tup)))

  # Parse and evaluate
  (def p (parser/new))
  (var pindex 0)
  (def len (length code))
  (if (= len 0) (parser/eof p))
  (while (> len pindex)
    (+= pindex (parser/consume p code pindex))
    (while (parser/has-more p)
      (prod-and-eval p)
      (if (env :exit) (break)))
    (when (= :error (parser/status p))
      (parse-err p where)
      (if (env :exit) (break))))

  # Check final parser state
  (unless (env :exit)
    (parser/eof p)
    (while (parser/has-more p)
      (prod-and-eval p)
      (if (env :exit) (break)))
    (when (= :error (parser/status p))
      (parse-err p where)))

  (put env :exit nil)
  (in env :exit-value))

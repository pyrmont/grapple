(import ./evaluator :as eval)


(var env (make-env))
(def sessions @{})
(var sess-counter 0)
(def sentinel @"")


(def ops
  {"sess/new" {:req ["id"]}
   "sess/end" {:req ["id" "sess"]}
   "sess/list" {:req ["id" "sess"]}
   "serv/info" {:req ["id" "sess"]}
   "serv/stop" {:req ["id" "sess"]}
   "serv/relo" {:req ["id" "sess"]}
   "env/eval" {:req ["id" "sess" "code"]}
   "env/load" {:req ["id" "sess" "path"]}
   "env/stop" {:req ["id" "sess" "req"]}
   "env/doc" {:req ["id" "sess" "sym"]}
   "env/compl" {:req ["id" "sess" "sym"]}})


(defn- make-sess []
  (set sess-counter (inc sess-counter))
  (def sess-id (string sess-counter))
  (put sessions sess-id true)
  sess-id)


(defn- end-sess [sess-id]
  (put sessions sess-id nil))


(defn- make-send-err [send]
  (fn sender [&named to msg src line col st]
    (def {"id" id "sess" sess "op" op} to)
    (send {"tag" "err"
           "req" id
           "sess" sess
           "op" op
           "msg" msg
           "src" src
           "line" line
           "col" col
           "st" st})
    (error sentinel)))


(defn- info-msg []
  {"ver" "mrepl/1"
   "lang" (string "janet/" janet/version)
   "os" (string (os/which))
   "arch" (string (os/arch))})


(defn confirm [req &named has else]
  (each k has
    (unless (req k)
      (else :to req :msg (string "request missing key \"" k "\"")))))


(defn handle-sess-new [req send send-err]
  (def id (req "id"))
  (def sess (make-sess))
  (unless sess
    (send-err :to req :msg "failed to start session"))
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "sess/new"
         "val" (info-msg)}))


(defn handle-sess-end [req send send-err]
  (def {"id" id "sess" sess} req)
  (end-sess sess)
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "sess/end"
         "val" "Session ended."}))


(defn handle-sess-list [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "sess/list"
         "val" (keys sessions)}))


(defn handle-serv-info [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "serv/info"
         "val" (info-msg)}))


# TODO: implement
(defn handle-serv-stop [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "serv/stop"
         "val" "Server shutting down..."}))


# TODO: implement
(defn handle-serv-relo [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "serv/relo"
         "val" "Server reloading..."}))


(defn handle-env-eval [req send send-err]
  (def {"id" id "sess" sess "code" code "path" path} req)
  (def p (parser/new))
  (def res (eval/run code :env env :path path :parser p :req req :send send :send-err send-err))
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "env/eval"
         "val" (string/format "%q" res)}))


(defn handle-env-load [req send send-err]
  (def {"id" id "sess" sess "path" path} req)
  (def p (parser/new))
  (def res (eval/run (slurp path) :env env :path path :parser p :req req :send send :send-err send-err))
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "env/load"
         "val" (string/format "%q" res)}))


(defn handle-env-doc [req send send-err]
  (def {"id" id "sess" sess "sym" sym} req)
  (def buf @"")
  (resume (fiber/new (fn [] (setdyn :out buf) (doc* (symbol sym))) : env))
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "env/doc"
         "val" (string buf)}))


(defn handle-env-cmpl [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "req" id
         "sess" sess
         "op" "env/cmpl"
         "val" nil}))


(defn handle [req send]
  (def send-err (make-send-err send))
  (try
    (do
      (def op (req "op"))
      (def spec (ops op))
      (unless spec
        (send-err :to req :msg "unsupported operation"))
      (confirm req :has (spec :req) :else send-err)
      (case op
        "sess/new" (handle-sess-new req send send-err)
        "sess/end" (handle-sess-end req send send-err)
        "sess/list" (handle-sess-list req send send-err)
        "serv/info" (handle-serv-info req send send-err)
        "serv/stop" (handle-serv-stop req send send-err)
        "serv/relo" (handle-serv-relo req send send-err)
        "env/eval" (handle-env-eval req send send-err)
        "env/load" (handle-env-load req send send-err)
        "env/stop" (send-err :to req :msg "unsupported operation")
        "env/doc" (handle-env-doc req send send-err)
        "env/cmpl" (handle-env-cmpl req send send-err))
      true)
    ([e fib]
     (if (= sentinel e)
       false
       (propagate e fib)))))

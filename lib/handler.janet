(import ./evaluator :as eval)

(def lang "net.inqk/janet")
(def match-max 20)


(var env (make-env))
(def sessions @{})
(var sess-counter 0)
(def sentinel @"")


(def ops
  {"sess/new" {:req ["lang" "id"]}
   "sess/end" {:req ["lang" "id" "sess"]}
   "sess/list" {:req ["lang" "id" "sess"]}
   "serv/info" {:req ["lang" "id" "sess"]}
   "serv/stop" {:req ["lang" "id" "sess"]}
   "serv/relo" {:req ["lang" "id" "sess"]}
   "env/eval" {:req ["lang" "id" "sess" "code"]}
   "env/load" {:req ["lang" "id" "sess" "path"]}
   "env/stop" {:req ["lang" "id" "sess" "req"]}
   "env/doc" {:req ["lang" "id" "sess" "sym"]}
   "env/cmpl" {:req ["lang" "id" "sess" "sym"]}})


(defn- make-sess []
  (set sess-counter (inc sess-counter))
  (def sess-id (string sess-counter))
  (put sessions sess-id true)
  sess-id)


(defn- end-sess [sess-id]
  (put sessions sess-id nil))


(defn- make-send-err [send]
  (fn sender [&named to msg src line col st]
    (def {"op" op "id" id "sess" sess} to)
    (send {"tag" "err"
           "op" op
           "lang" lang
           "req" id
           "sess" sess
           "msg" msg
           "src" src
           "line" line
           "col" col
           "st" st})
    (error sentinel)))


(defn- info-msg []
  {"ver" "mrepl/1"
   "lang" lang
   "impl" (string "janet/" janet/version)
   "os" (string (os/which))
   "arch" (string (os/arch))})


(defn- literalise [x]
  (string/format "%q" x))


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
         "op" "sess/new"
         "lang" lang
         "req" id
         "sess" sess
         "val" (info-msg)}))


(defn handle-sess-end [req send send-err]
  (def {"id" id "sess" sess} req)
  (end-sess sess)
  (send {"tag" "ret"
         "op" "sess/end"
         "lang" lang
         "req" id
         "sess" sess
         "val" "Session ended."}))


(defn handle-sess-list [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "op" "sess/list"
         "lang" lang
         "req" id
         "sess" sess
         "val" (keys sessions)}))


(defn handle-serv-info [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "op" "serv/info"
         "lang" lang
         "req" id
         "sess" sess
         "val" (info-msg)}))


# TODO: implement
(defn handle-serv-stop [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "op" "serv/stop"
         "lang" lang
         "req" id
         "sess" sess
         "val" "Server shutting down..."}))


# TODO: implement
(defn handle-serv-relo [req send send-err]
  (def {"id" id "sess" sess} req)
  (send {"tag" "ret"
         "op" "serv/relo"
         "lang" lang
         "req" id
         "sess" sess
         "val" "Server reloading..."}))


(defn handle-env-eval [req send send-err]
  (def {"id" id "sess" sess "code" code "path" path} req)
  (def p (parser/new))
  (def res (eval/run code :env env :path path :parser p :req req :send send :send-err send-err))
  (send {"tag" "ret"
         "op" "env/eval"
         "lang" lang
         "req" id
         "sess" sess
         "val" (literalise res)}))


(defn handle-env-load [req send send-err]
  (def {"id" id "sess" sess "path" path} req)
  (def p (parser/new))
  (def res (eval/run (slurp path) :env env :path path :parser p :req req :send send :send-err send-err))
  (send {"tag" "ret"
         "op" "env/load"
         "lang" lang
         "req" id
         "sess" sess
         "val" (literalise res)}))


(defn handle-env-doc [req send send-err]
  (def {"id" id "sess" sess "sym" sym} req)
  (def buf @"")
  (def bind (env (symbol sym)))
  (send {"tag" "ret"
         "op" "env/doc"
         "lang" lang
         "req" id
         "sess" sess
         "val" (bind :doc)
         "janet/type" (string (type (bind :value)))
         "janet/sm" (bind :source-map)}))


(defn handle-env-cmpl [req send send-err]
  (def {"id" id
        "sess" sess
        "sym" sym-str
        "max" user-max
        "janet/type" sym_t} req)
  (def sym (case sym_t
             "symbol" (symbol sym-str)
             "keyword" (keyword sym-str)
             sym-str))
  (def matches @[])
  (def max (or user-max match-max))
  (def slen (length sym))
  (var t env)
  (while t
    (each key (keys t)
      (if (and (<= slen (length key))
               (= sym (case (type key)
                        :symbol (symbol/slice key 0 slen)
                        :keyword (keyword/slice key 0 slen)
                        :string (string/slice key 0 slen))))
        (array/push matches (string key)))
      (if (= max (length matches))
       (break)))
    (if (= max (length matches))
      (set t nil)
      (set t (table/getproto t))))
  (send {"tag" "ret"
         "op" "env/cmpl"
         "lang" lang
         "req" id
         "sess" sess
         "val" matches}))


(defn handle [req send]
  (def send-err (make-send-err send))
  (try
    (do
      (def op (req "op"))
      (def spec (ops op))
      (unless spec
        (send-err :to req :msg "unsupported operation"))
      (confirm req :has (spec :req) :else send-err)
      (unless (= lang (req "lang"))
        (send-err :to req :msg "unsupported language version"))
      (case op
        "sess/new" (handle-sess-new req send send-err)
        "sess/end" (handle-sess-end req send send-err)
        "sess/list" (handle-sess-list req send send-err)
        "serv/info" (handle-serv-info req send send-err)
        "serv/stop" (handle-serv-stop req send send-err)
        "serv/relo" (handle-serv-relo req send send-err)
        "env/eval" (handle-env-eval req send send-err)
        "env/load" (handle-env-load req send send-err)
        "env/stop" (send-err :to req :msg "operation not implemented")
        "env/doc" (handle-env-doc req send send-err)
        "env/cmpl" (handle-env-cmpl req send send-err))
      true)
    ([e fib]
     (if (= sentinel e)
       false
       (propagate e fib)))))

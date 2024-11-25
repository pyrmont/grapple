(import ./utilities :as util)
(import ./evaluator :as eval)


(var env (make-env))
(def sessions @{})
(var sess-counter 0)
(def match-max 20)


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


(defn confirm [req ks send-err]
  (each k ks
    (unless (req k)
      (send-err (string "request missing key \"" k "\""))
      (break false)))
  true)


(defn- info-msg []
  {"ver" "mrepl/1"
   "lang" util/lang
   "impl" (string "janet/" janet/version)
   "os" (string (os/which))
   "arch" (string (os/arch))})


(defn- end-sess [sess-id]
  (put sessions sess-id nil))


(defn- make-sess []
  (set sess-counter (inc sess-counter))
  (def sess-id (string sess-counter))
  (put sessions sess-id true)
  sess-id)


# Handle functions

(defn handle-sess-new [req send-ret send-err]
  (def id (req "id"))
  (def sess (make-sess))
  (unless sess
    (send-err "failed to start session"))
  (send-ret (info-msg) {"sess" sess}))


(defn handle-sess-end [req send-ret send-err]
  (def {"id" id "sess" sess} req)
  (end-sess sess)
  (send-ret "Session ended."))


(defn handle-sess-list [req send-ret send-err]
  (def {"id" id "sess" sess} req)
  (send-ret (keys sessions)))


(defn handle-serv-info [req send-ret send-err]
  (def {"id" id "sess" sess} req)
  (send-ret (info-msg)))


# TODO: implement
(defn handle-serv-stop [req send-ret send-err]
  (def {"id" id "sess" sess} req)
  (send-ret "Server shutting down..."))


# TODO: implement
(defn handle-serv-relo [req send-ret send-err]
  (def {"id" id "sess" sess} req)
  (send-ret "Server reloading..."))


(defn handle-env-eval [req send-ret send-err send]
  (def {"id" id "sess" sess "code" code "path" path} req)
  (def res (eval/run code
                     :env env
                     :path path
                     :ret send-ret
                     :out-1 (util/make-send-out send req "out")
                     :out-2 (util/make-send-out send req "err")
                     :err send-err))
  (send-ret nil))


(defn handle-env-load [req send-ret send-err send]
  (def {"id" id "sess" sess "path" path} req)
  (def code (slurp path))
  (def res (eval/run code
                     :env env
                     :path path
                     :ret send-ret
                     :out-1 (util/make-send-out send req "out")
                     :out-2 (util/make-send-out send req "err")
                     :err send-err))
  (send-ret nil))


(defn handle-env-doc [req send-ret send-err]
  (def {"id" id "sess" sess "sym" sym} req)
  (def buf @"")
  (def bind (env (symbol sym)))
  (send-ret (bind :doc) {"janet/type" (string (type (bind :value)))
                         "janet/sm" (bind :source-map)}))


(defn handle-env-cmpl [req send-ret send-err]
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
  (send-ret matches))


(defn handle [req send]
  (def send-ret (util/make-send-ret send req))
  (def send-err (util/make-send-err send req))
  (do
    (def op (req "op"))
    (def spec (ops op))
    (unless spec
      (send-err "unsupported operation")
      (break false))
    (unless (confirm req (spec :req) send-err)
      (break false))
    (unless (= util/lang (req "lang"))
      (send-err "unsupported language version")
      (break false))
    (case op
      "sess/new" (handle-sess-new req send-ret send-err)
      "sess/end" (handle-sess-end req send-ret send-err)
      "sess/list" (handle-sess-list req send-ret send-err)
      "serv/info" (handle-serv-info req send-ret send-err)
      "serv/stop" (handle-serv-stop req send-ret send-err)
      "serv/relo" (handle-serv-relo req send-ret send-err)
      "env/eval" (handle-env-eval req send-ret send-err send)
      "env/load" (handle-env-load req send-ret send-err send)
      "env/stop" (send-err "operation not implemented")
      "env/doc" (handle-env-doc req send-ret send-err)
      "env/cmpl" (handle-env-cmpl req send-ret send-err))
    true))

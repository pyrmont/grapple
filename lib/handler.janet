(import ./utilities :as util)
(import ./evaluator :as eval)


(def match-max 20)


(def ops
  {"sess.new" {:req ["lang" "id"]}
   "sess.end" {:req ["lang" "id" "sess"]}
   "sess.list" {:req ["lang" "id" "sess"]}
   "serv.info" {:req ["lang" "id" "sess"]}
   "serv.stop" {:req ["lang" "id" "sess"]}
   "serv.relo" {:req ["lang" "id" "sess"]}
   "env.eval" {:req ["lang" "id" "sess" "code" "ns"]}
   "env.load" {:req ["lang" "id" "sess" "path"]}
   "env.stop" {:req ["lang" "id" "sess" "req"]}
   "env.doc" {:req ["lang" "id" "sess" "sym" "ns"]}
   "env.cmpl" {:req ["lang" "id" "sess" "sym" "ns"]}})


(defn confirm [req ks send-err]
  (each k ks
    (unless (req k)
      (send-err (string "request missing key \"" k "\""))
      (break false)))
  true)


(def- info-kvs
  {"janet/impl" ["janet" janet/version]
   "janet/os" (os/which)
   "janet/arch" (os/arch)
   "janet/prot" util/prot
   "janet/serv" util/proj})



(defn- end-sess [sessions sess-id]
  (put (sessions :clients) sess-id nil))


(defn- make-sess [sessions]
  (def count (inc (sessions :count)))
  (put sessions :count count)
  (def sess-id (string count))
  (put (sessions :clients) sess-id true)
  sess-id)


# Handle functions

(defn sess-new [req sns send-ret send-err]
  (def sess (make-sess sns))
  (unless sess
    (send-err "failed to start session")
    (break))
  (send-ret nil (merge {"sess" sess} info-kvs)))


(defn sess-end [req sns send-ret send-err]
  (def sess (req "sess"))
  (end-sess sns sess)
  (send-ret nil))


(defn sess-list [req sns send-ret send-err]
  (send-ret (keys (sns :clients))))


(defn serv-info [req sns send-ret send-err]
  (send-ret nil info-kvs))


# TODO: implement
(defn serv-stop [req sns send-ret send-err]
  (send-ret "Server shutting down..."))


# TODO: implement
(defn serv-relo [req sns send-ret send-err]
  (send-ret "Server reloading..."))


(defn env-eval [req sns send-ret send-err send]
  (def {"code" code "ns" ns "path" path} req)
  (unless (string? code)
    (send-err "code must be string")
    (break))
  (unless (or (nil? path) (string? path))
    (send-err "path must be string"))
  (def eval-env (or (module/cache ns)
                    (do
                      (def new-env (eval/eval-make-env))
                      (put module/cache ns new-env)
                      new-env)))
  (def res (eval/run code
                     :env eval-env
                     :path path
                     :send send
                     :req req))
  (send-ret res))


(defn env-load [req sns send-ret send-err send]
  (def {"path" path} req)
  (def code (slurp path))
  (def eval-env (or (module/cache path)
                    (do
                      (def new-env (make-env))
                      (put module/cache path new-env)
                      new-env)))
  (def res (eval/run code
                     :env eval-env
                     :path path
                     :send send
                     :req req))
  (send-ret res))


(defn env-doc [req sns send-ret send-err]
  (def {"sym" sym-str
        "ns" ns} req)
  (def sym (case (sym-str 0)
             34 (string/slice sym-str 1 -2)
             58 (keyword (string/slice sym-str 1))
             (symbol sym-str)))
  (def eval-env (or (module/cache ns)
                    root-env))
  (def bind (eval-env sym))
  (if bind
    (send-ret (bind :doc) {"janet/type" (type (bind :value))
                           "janet/sm" (bind :source-map)})
    (send-err (string sym-str " not found"))))


(defn env-cmpl [req sns send-ret send-err]
  (def {"sym" sym-str
        "ns" ns
        "max" user-max
        "janet/type" sym_t} req)
  (def sym (case sym_t
             "symbol" (symbol sym-str)
             "keyword" (keyword sym-str)
             sym-str))
  (def matches @[])
  (def max (or user-max match-max))
  (def slen (length sym))
  (var t (or (module/cache ns)
             root-env))
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


(defn handle [req sns send]
  (def send-ret (util/make-send-ret req send))
  (def send-err (util/make-send-err req send))
  (try
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
        "sess.new" (sess-new req sns send-ret send-err)
        "sess.end" (sess-end req sns send-ret send-err)
        "sess.list" (sess-list req sns send-ret send-err)
        "serv.info" (serv-info req sns send-ret send-err)
        "serv.stop" (serv-stop req sns send-ret send-err)
        "serv.relo" (serv-relo req sns send-ret send-err)
        "env.eval" (env-eval req sns send-ret send-err send)
        "env.load" (env-load req sns send-ret send-err send)
        "env.stop" (send-err "operation not implemented")
        "env.doc" (env-doc req sns send-ret send-err)
        "env.cmpl" (env-cmpl req sns send-ret send-err))
      # return value
      true)
    ([e f]
     # (debug/stacktrace f)
     (send-err (string "request failed: " e)))))

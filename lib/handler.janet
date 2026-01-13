(import ./utilities :as util)
(import ./evaluator :as eval)
(import ./deps :as deps)

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
   "env.cmpl" {:req ["lang" "id" "sess" "sym" "ns"]}
   "dbg.brk.add" {:req ["lang" "id" "sess" "path" "line"]}
   "dbg.brk.rem" {:req ["lang" "id" "sess" "bp-id"]}
   "dbg.brk.clr" {:req ["lang" "id" "sess"]}
   "dbg.step.cont" {:req ["lang" "id" "sess"]}
   "dbg.insp.stk" {:req ["lang" "id" "sess"]}})

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
  (put (sessions :clients) sess-id @{:dep-graph @{}
                                     :breakpoints @[]})
  sess-id)

# Handle functions

(defn sess-new [req sns send-ret send-err]
  # Check if authentication is required
  (when (def expected-token (sns :token))
    (def provided-token (req "auth"))
    (unless (= expected-token provided-token)
      (send-err "authentication failed")
      (break)))
  # Create session as normal
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
  (def {"code" code
        "ns" ns
        "line" line
        "col" col
        "sess" sess-id} req)
  (unless (string? code)
    (send-err "code must be string")
    (break))
  (unless (or (nil? ns) (string? ns))
    (send-err "ns must be string"))
  (def eval-env (or (module/cache ns)
                    (do
                      (def new-env (eval/eval-make-env))
                      (put module/cache ns new-env)
                      new-env)))
  (def parser (parser/new))
  (when (and line col)
    (parser/where parser line col))
  (def sess (get-in sns [:clients sess-id]))
  # Run evaluation in a fiber to allow yielding on breakpoints
  (def eval-fiber
    (fiber/new
      (fn []
        (eval/run code
                  :env eval-env
                  :parser parser
                  :path ns
                  :send send
                  :req req
                  :sess sess))
      :d))
  (def res (resume eval-fiber))
  # Check if fiber is in debug state (store state if it is)
  (if (= :debug (fiber/status eval-fiber))
    (put sess :paused {:fiber eval-fiber
                       :req req
                       :send send})
    (send-ret res)))

(defn env-load [req sns send-ret send-err send]
  (def {"path" path "sess" sess-id} req)
  (def code (slurp path))
  (def eval-env (or (module/cache path)
                    (do
                      (def new-env (eval/eval-make-env))
                      (put module/cache path new-env)
                      new-env)))
  (def sess (get-in sns [:clients sess-id]))
  # Clear dependency graph for this file before reloading
  # This prevents cascading re-evaluations during file load
  # But preserve :importers information as it represents external relationships
  (when-let [graph (get-in sess [:dep-graph path])]
    (deps/clear-graph graph :keep-imports? true))
  (def res (eval/run code
                     :env eval-env
                     :path path
                     :send send
                     :req req
                     :sess sess))
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
    (send-ret (or (bind :doc) "No documentation found.")
              {"janet/type" (type (bind :value))
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
  (send-ret (sort matches)))

(defn dbg-brk-add [req sns send-ret send-err]
  (def {"path" path
        "line" line
        "col" col
        "sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  # set breakpoint
  (def column (or col 1))
  (debug/break path line column)
  # find the binding that contains this line
  (def env (module/cache path))
  (var binding-sym nil)
  (var max-line 0)
  (when env
    (eachp [sym binding] env
      (when (and (table? binding) (binding :source-map))
        (def sm (binding :source-map))
        (when (tuple? sm)
          (def [sm-path sm-line] sm)
          (when (and (= sm-path path)
                     (<= sm-line line)
                     (> sm-line max-line))
            (set max-line sm-line)
            (set binding-sym sym))))))
  # save breakpoint
  (def bp-info {:path path
                :line line
                :col column
                :binding binding-sym})
  (array/push (sess :breakpoints) bp-info)
  (def bp-id (dec (length (sess :breakpoints))))
  (send-ret nil {"janet/bp-id" bp-id}))

(defn dbg-brk-rem [req sns send-ret send-err]
  (def {"bp-id" bp-id
        "sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  (def bp-info (get-in sess [:breakpoints bp-id]))
  (unless bp-info
    (send-err "invalid breakpoint id")
    (break))
  (def {:path path :line line :col column} bp-info)
  (debug/unbreak path line column)
  (put-in sess [:breakpoints bp-id] nil)
  (send-ret nil {"janet/bp-id" bp-id}))

(defn dbg-brk-clr [req sns send-ret send-err]
  (def {"sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  # Clear all breakpoints for this session
  (def breakpoints (sess :breakpoints))
  (each bp breakpoints
    (when bp
      (debug/unbreak (bp :path) (bp :line) (bp :col))))
  (array/clear breakpoints)
  (send-ret nil))

(defn dbg-step-cont [req sns send-ret send-err]
  (def {"sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  (def paused (sess :paused))
  (unless (and paused (paused :fiber))
    (send-err "no paused fiber")
    (break))
  # Get original request context
  (def orig-req (paused :req))
  (def orig-send (paused :send))
  (def orig-ret (util/make-send-ret orig-req orig-send))
  (def orig-err (util/make-send-err orig-req orig-send))
  # Resume paused fiber
  (def result (resume (paused :fiber) :continue))
  (def status (fiber/status (paused :fiber)))
  (unless (= status :debug)
    (put sess :paused nil))
  # Handle based on fiber status
  (case status
    :dead
    (orig-ret result)
    :debug
    nil
    (orig-err (string "fiber status: " status)))
  (send-ret nil))

(defn dbg-insp-stk [req sns send-ret send-err]
  (def {"sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  (def paused (sess :paused))
  (unless (and paused (paused :fiber))
    (send-err "no paused fiber")
    (break))
  # Resume paused fiber
  (def frame-data (resume (paused :fiber) :stack))
  (send-ret (string/format "%q" frame-data)))

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
        "env.cmpl" (env-cmpl req sns send-ret send-err)
        "dbg.brk.add" (dbg-brk-add req sns send-ret send-err)
        "dbg.brk.rem" (dbg-brk-rem req sns send-ret send-err)
        "dbg.brk.clr" (dbg-brk-clr req sns send-ret send-err)
        "dbg.step.cont" (dbg-step-cont req sns send-ret send-err)
        "dbg.insp.stk" (dbg-insp-stk req sns send-ret send-err))
      # return value
      true)
    ([e f]
     (def frames (debug/stack f))
     (def top-frame (first frames))
     (def details (when top-frame
                    {"janet/path" (top-frame :source)
                     "janet/line" (top-frame :source-line)
                     "janet/col" (top-frame :source-column)
                     "janet/stack" (util/stack f)}))
     (send-err (string "request failed: " e) details))))

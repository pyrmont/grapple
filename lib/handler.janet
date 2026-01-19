(import ./utilities :as util)
(import ./evaluator :as eval)
(import ./deps :as deps)

(def match-max 20)

(def ops
  {"brk.add" {:req ["lang" "id" "sess" "path" "janet/form" "janet/rline" "janet/rcol"]}
   "brk.clr" {:req ["lang" "id" "sess"]}
   "brk.list" {:req ["lang" "id" "sess"]}
   "brk.rem" {:req ["lang" "id" "sess" "bp-id"]}
   "env.cmpl" {:req ["lang" "id" "sess" "sym" "ns"]}
   "env.dbg" {:req ["lang" "id" "sess" "code" "req"]}
   "env.doc" {:req ["lang" "id" "sess" "sym" "ns"]}
   "env.eval" {:req ["lang" "id" "sess" "code" "ns"]}
   "env.load" {:req ["lang" "id" "sess" "path"]}
   "env.stop" {:req ["lang" "id" "sess" "req"]}
   "serv.info" {:req ["lang" "id" "sess"]}
   "serv.relo" {:req ["lang" "id" "sess"]}
   "serv.stop" {:req ["lang" "id" "sess"]}
   "sess.end" {:req ["lang" "id" "sess"]}
   "sess.list" {:req ["lang" "id" "sess"]}
   "sess.new" {:req ["lang" "id"]}})

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

(defn- find-form-at-location [form target-line target-col]
  (defn walk [f]
    (unless (tuple? f)
      (break))
    (def [line col] (tuple/sourcemap f))
    (cond
      (> line target-line)
      (break)
      (and (= line target-line)
           (= col target-col))
      (break {:line line :col col}))
    (var res nil)
    (each el f
      (set res (walk el))
      (unless (nil? res)
        (break)))
    res)
  (walk form))

(defn- make-sess [sessions]
  (def count (inc (sessions :count)))
  (put sessions :count count)
  (def sess-id (string count))
  (put (sessions :clients) sess-id @{:dep-graph @{}
                                     :breakpoints @[]})
  sess-id)

# Handle functions

## Breakpoint operations

(defn brk-add [req sns send-ret send-err]
  (def {"path" path
        "janet/rline" rel-line
        "janet/rcol" rel-col
        "janet/form" client-form
        "sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  # parse the client form
  (def parsed-client-form (parse client-form))
  # get the dependency graph for this file
  (def dep-graph (get-in sess [:dep-graph path] {:sources {}}))
  # find binding by matching form content
  (var binding-sym nil)
  (var eval-line nil)
  (var eval-col nil)
  (var stored-form nil)
  (eachp [sym source-info] (dep-graph :sources)
    (when (deep= (source-info :form) parsed-client-form)
      (set binding-sym sym)
      (set eval-line (source-info :line))
      (set eval-col (source-info :col))
      (set stored-form (source-info :form))
      (break)))
  (unless binding-sym
    (send-err "no matching form, evaluate root form before adding breakpoint")
    (break))
  (def abs-line (+ eval-line rel-line))
  (def abs-col (if (zero? rel-line)
                 (+ eval-col (or rel-col 0))
                 (or rel-col 1)))
  # Janet breakpoints must be set to beginning of form
  (def found-form (find-form-at-location stored-form abs-line abs-col))
  (unless found-form
    (send-err "Breakpoint must be added at the start of a form")
    (break))
  # set breakpoint
  (debug/break path abs-line abs-col)
  # save breakpoint
  (def bp-info {:path path
                :line abs-line
                :col abs-col
                :binding binding-sym})
  (array/push (sess :breakpoints) bp-info)
  (def bp-id (dec (length (sess :breakpoints))))
  (send-ret nil {"janet/bp-id" bp-id}))

(defn brk-clr [req sns send-ret send-err]
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

(defn brk-list [req sns send-ret send-err]
  (def {"sess" sess-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  # Return list of breakpoints with their IDs
  (def breakpoints (sess :breakpoints))
  (def bp-list @[])
  (eachk i breakpoints
    (def bp (get breakpoints i))
    (when bp
      (array/push bp-list {:id i
                           :path (bp :path)
                           :line (bp :line)
                           :col (bp :col)
                           :binding (string (bp :binding))})))
  (send-ret (string/format "%q" bp-list)))

(defn brk-rem [req sns send-ret send-err]
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

## Environment operations

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

(defn env-dbg [req sns send-ret send-err send]
  (def {"code" code
        "sess" sess-id
        "req" orig-req-id} req)
  (def sess (get-in sns [:clients sess-id]))
  (unless sess
    (send-err "invalid session")
    (break))
  (def paused (sess :paused))
  (unless (and paused (paused :fiber))
    (send-err "no paused fiber")
    (break))
  (def eval-fiber (paused :fiber))
  (def signal (paused :signal))
  (def send-sig (util/make-send-sig req send))
  # Evaluate code in debug environment
  (def debug-fiber
   (fiber/new
     (fn []
       (eval/run-debug code eval-fiber signal
                       :send send
                       :req req
                       :sess sess))
     :d))
  (def res (resume debug-fiber))
  (if (= :debug (fiber/status debug-fiber))
    (do
      (put sess :paused {:fiber eval-fiber
                         :signal :debug
                         :req req
                         :send send})
      (send-err "breakpoint inside debugging environment"))
    (send-ret res))
  # Check if eval-fiber is still in debug state (e.g., after .step)
  (if (= :debug (fiber/status eval-fiber))
    (do
      # Get the inner paused fiber to extract its state
      (def inner-fiber (resume eval-fiber :fiber))
      # Send debug signal with the correct location
      (send-sig "debug" (util/debug-payload inner-fiber :debug)))
    # Otherwise clear the paused fiber
    (put sess :paused nil)))

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
  # Check if fiber is in debug state (store the actual paused fiber)
  (if (= :debug (fiber/status eval-fiber))
    # res is the actual paused fiber yielded by debugger-on-status
    (put sess :paused {:fiber eval-fiber
                       :signal :debug
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

## Session operations

(defn sess-end [req sns send-ret send-err]
  (def sess (req "sess"))
  (end-sess sns sess)
  (send-ret nil))

(defn sess-list [req sns send-ret send-err]
  (send-ret (keys (sns :clients))))

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

## Management operations

(defn serv-info [req sns send-ret send-err]
  (send-ret nil info-kvs))

# TODO: implement
(defn serv-relo [req sns send-ret send-err]
  (send-ret "Server reloading..."))

# TODO: implement
(defn serv-stop [req sns send-ret send-err]
  (send-ret "Server shutting down..."))

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
        "brk.add" (brk-add req sns send-ret send-err)
        "brk.clr" (brk-clr req sns send-ret send-err)
        "brk.list" (brk-list req sns send-ret send-err)
        "brk.rem" (brk-rem req sns send-ret send-err)
        "env.cmpl" (env-cmpl req sns send-ret send-err)
        "env.dbg" (env-dbg req sns send-ret send-err send)
        "env.doc" (env-doc req sns send-ret send-err)
        "env.eval" (env-eval req sns send-ret send-err send)
        "env.load" (env-load req sns send-ret send-err send)
        "env.stop" (send-err "operation not implemented")
        "serv.info" (serv-info req sns send-ret send-err)
        "serv.relo" (serv-relo req sns send-ret send-err)
        "serv.stop" (serv-stop req sns send-ret send-err)
        "sess.end" (sess-end req sns send-ret send-err)
        "sess.new" (sess-new req sns send-ret send-err)
        "sess.list" (sess-list req sns send-ret send-err))
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

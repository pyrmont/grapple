(def lang "net.inqk/janet-1.0")
(def proj ["grapple" "1.0.0-dev"])
(def prot ["mrepl" "1"])
(def ns "<mrepl>")

(def- log-levels {:off 0 :normal 1 :debug 2})
(var- log-level :normal)

(defn set-log-level [level]
  (set log-level level))

(defn log [msg &opt level io]
  (default level :normal)
  (def log-index (log-levels log-level))
  (when log-index
    (def msg-index (log-levels level))
    (def s (if (string? msg) msg (string/format "%q" msg)))
    (when (>= log-index msg-index)
      (def prefix
        (when (= log-index 2)
          (case io
            :in
            "[DBG] (in) "
            :out
            "[DBG] (out) "
            # default
            "[DBG] ")))
      (printf (string prefix "%s") s))))

(defn make-send-cmd [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :cmd-sender [val &opt details]
    (def resp @{"tag" "cmd"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-dbg [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :dbg-sender [val &opt details]
    (def resp @{"tag" "dbg"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-err [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :err-sender [val &opt details]
    (def resp @{"tag" "err"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-note [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :note-sender [val &opt details]
    (def resp @{"tag" "note"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-out [req send ch]
  (def {"op" op "id" id "sess" sess} req)
  (fn :out-sender [val]
    (send {"tag" "out"
           "op" op
           "lang" lang
           "req" id
           "sess" sess
           "ch" ch
           "val" val})))

(defn make-send-ret [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :ret-sender [val &opt details]
    (def resp @{"tag" "ret"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "done" true
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn make-send-sig [req send]
  (def {"op" op "id" id "sess" sess} req)
  (fn :sig-sender [val &opt details]
    (def resp @{"tag" "sig"
                "op" op
                "lang" lang
                "req" id
                "sess" sess
                "val" val})
    (send (cond
            (nil? details)
            resp
            (dictionary? details)
            (merge-into resp details)
            # default
            (error "invalid argument: must be nil or dictionary")))))

(defn stack [f]
  (map (fn [fr] {:name (fr :name)
                 :path (fr :source)
                 :line (fr :source-line)
                 :col  (fr :source-column)
                 :pc (fr :pc)
                 :tail (fr :tail)
                 :function (string/format "%q" (fr :function))
                 :slots (string/format "%q" (fr :slots))
                 :locals (string/format "%q" (fr :locals))})
       (debug/stack f)))

(defn safe-disasm [func]
  "Disassemble a function and convert to JSON-safe format"
  (def dasm (disasm func))
  {:arity (dasm :arity)
   :min-arity (dasm :min-arity)
   :max-arity (dasm :max-arity)
   :vararg (dasm :vararg)
   :structarg (dasm :structarg)
   :source (dasm :source)
   :name (dasm :name)
   :slotcount (dasm :slotcount)
   :bytecode (string (dasm :bytecode))
   :constants (string (dasm :constants))
   :sourcemap (dasm :sourcemap)
   :symbolmap (string (dasm :symbolmap))
   :environments (string (dasm :environments))
   :defs (string (dasm :defs))})

(defn fiber-state
  "Returns fiber state information (metadata) as a string"
  [fiber signal &opt n]
  (def frame (in (debug/stack fiber) (or n 0)))
  (def func (frame :function))
  (def dasm (disasm func))
  (def buf @"")
  (buffer/push-string buf "  status:     " (string (fiber/status fiber)))
  (buffer/push-string buf "\n  function:   " (get dasm :name "<anonymous>") " [" (in dasm :source "") "]")
  (when-let [constants (dasm :constants)]
    (buffer/format buf "\n  constants:  %.4q" constants))
  (buffer/format buf "\n  slots:      %.4q" (frame :slots))
  (string buf))

(defn bytecode-instructions
  "Returns formatted bytecode instructions as a string"
  [fiber signal &opt n]
  (def frame (in (debug/stack fiber) (or n 0)))
  (def func (frame :function))
  (def dasm (disasm func))
  (def bytecode (in dasm :bytecode))
  (def pc (frame :pc))
  (def sourcemap (in dasm :sourcemap))
  (var last-loc [-2 -2])
  (def buf @"")
  (def padding (string/repeat " " 20))
  (loop [i :range [0 (length bytecode)]
         :let [instr (bytecode i)]]
    (buffer/push-string buf (if (= (tuple/type instr) :brackets) "*" " "))
    (buffer/push-string buf (if (= i pc) "> " "  "))
    (buffer/format buf "%.20s" (string (string/join (map string instr) " ") padding))
    (when sourcemap
      (let [[sl sc] (sourcemap i)
            loc [sl sc]]
        (when (not= loc last-loc)
          (set last-loc loc)
          (buffer/push-string buf " # line " (string sl) ", column " (string sc)))))
    (buffer/push-string buf "\n"))
  (buffer/push-string buf "\n")
  (string buf))

(defn debug-payload
  "Creates a debug signal payload dictionary for the given fiber"
  [fiber signal]
  (def dbg-stack (debug/stack fiber))
  (def frame (first dbg-stack))
  {"janet/path" (frame :source)
   "janet/line" (frame :source-line)
   "janet/col" (frame :source-column)
   "janet/stack" (stack fiber)
   "janet/fiber-state" (fiber-state fiber signal)
   "janet/bytecode" (bytecode-instructions fiber signal)})

(defn ppasm
  "Returns pretty-printed assembly as a string (deprecated, use fiber-state + bytecode-instructions)"
  [fiber signal &opt n]
  (def frame (in (debug/stack fiber) (or n 0)))
  (def func (frame :function))
  (def dasm (disasm func))
  (def bytecode (in dasm :bytecode))
  (def pc (frame :pc))
  (def sourcemap (in dasm :sourcemap))
  (var last-loc [-2 -2])
  (def buf @"")
  (buffer/push-string buf "Disassembly\n")
  (buffer/push-string buf "===========\n")
  # (buffer/push-string buf "\n  signal:     " (string signal))
  (buffer/push-string buf "\n  status:     " (string (fiber/status fiber)))
  (buffer/push-string buf "\n  function:   " (get dasm :name "<anonymous>") " [" (in dasm :source "") "]")
  (when-let [constants (dasm :constants)]
    (buffer/format buf "\n  constants:  %.4q" constants))
  (buffer/format buf "\n  slots:      %.4q\n" (frame :slots))
  # (when-let [src-path (in dasm :source)]
  #   (when (and (os/stat src-path :mode)
  #              sourcemap)
  #     (defn dump
  #       [src cur]
  #       (def offset 5)
  #       (def beg (max 1 (- cur offset)))
  #       (def lines (array/concat @[""] (string/split "\n" src)))
  #       (def end (min (+ cur offset) (length lines)))
  #       (def digits (inc (math/floor (math/log10 end))))
  #       (def fmt-str (string "%" digits "d: %s"))
  #       (for i beg end
  #         (buffer/push-string buf " ")
  #         (buffer/push-string buf (if (= i cur) "> " "  "))
  #         (buffer/format buf fmt-str i (get lines i))
  #         (buffer/push-string buf "\n")))
  #     (let [[sl _] (sourcemap pc)]
  #       (dump (slurp src-path) sl)
  #       (buffer/push-string buf "\n"))))
  (buffer/push-string buf "\nInstructions:")
  (buffer/push-string buf "\n-------------\n")
  (def padding (string/repeat " " 20))
  (loop [i :range [0 (length bytecode)]
         :let [instr (bytecode i)]]
    (buffer/push-string buf (if (= (tuple/type instr) :brackets) "*" " "))
    (buffer/push-string buf (if (= i pc) "> " "  "))
    (buffer/format buf "%.20s" (string (string/join (map string instr) " ") padding))
    (when sourcemap
      (let [[sl sc] (sourcemap i)
            loc [sl sc]]
        (when (not= loc last-loc)
          (set last-loc loc)
          (buffer/push-string buf " # line " (string sl) ", column " (string sc)))))
    (buffer/push-string buf "\n"))
  (buffer/push-string buf "\n")
  (string buf))

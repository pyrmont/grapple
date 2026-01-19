(defn .fiber
  "Gets the current fiber being debugged"
  []
  (resume (dyn :fiber) :fiber))

(defn .signal
  "Gets the current signal being debugged"
  []
  (dyn :signal))

(defn .stack
  "Returns the current fiber stack as an array of frames"
  []
  (debug/stack (.fiber)))

(defn .frame
  "Shows a stack frame"
  [&opt n]
  (def stack (debug/stack (.fiber)))
  (in stack (or n 0)))

(defn .locals
  "Shows local bindings"
  [&opt n]
  (get (.frame n) :locals))

(defn .fn
  "Gets the current function"
  [&opt n]
  (in (.frame n) :function))

(defn .slots
  "Gets an array of slots in a stack frame"
  [&opt n]
  (in (.frame n) :slots))

(defn .slot
  "Gets the value of the nth slot"
  [&opt nth frame-idx]
  (in (.slots frame-idx) (or nth 0)))

(defn .disasm
  "Gets the assembly for the current function"
  [&opt n]
  (def frame (.frame n))
  (def func (frame :function))
  (disasm func))

(defn .bytecode
  "Get the bytecode for the current function"
  [&opt n]
  ((.disasm n) :bytecode))

(defn .ppasm
  "Returns pretty-printed assembly for the current function as a string"
  [&opt n]
  (def frame (.frame n))
  (def func (frame :function))
  (def dasm (disasm func))
  (def bytecode (in dasm :bytecode))
  (def pc (frame :pc))
  (def sourcemap (in dasm :sourcemap))
  (var last-loc [-2 -2])
  (def buf @"")
  (buffer/push-string buf "\n  signal:     " (string (.signal)))
  (buffer/push-string buf "\n  status:     " (string (fiber/status (.fiber))))
  (buffer/push-string buf "\n  function:   " (get dasm :name "<anonymous>") " [" (in dasm :source "") "]")
  (when-let [constants (dasm :constants)]
    (buffer/format buf "\n  constants:  %.4q" constants))
  (buffer/format buf "\n  slots:      %.4q\n" (frame :slots))
  (when-let [src-path (in dasm :source)]
    (when (and (os/stat src-path :mode)
               sourcemap)
      (defn dump
        [src cur]
        (def offset 5)
        (def beg (max 1 (- cur offset)))
        (def lines (array/concat @[""] (string/split "\n" src)))
        (def end (min (+ cur offset) (length lines)))
        (def digits (inc (math/floor (math/log10 end))))
        (def fmt-str (string "%" digits "d: %s"))
        (for i beg end
          (buffer/push-string buf " ")
          (buffer/push-string buf (if (= i cur) "> " "  "))
          (buffer/format buf fmt-str i (get lines i))
          (buffer/push-string buf "\n")))
      (let [[sl _] (sourcemap pc)]
        (dump (slurp src-path) sl)
        (buffer/push-string buf "\n"))))
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

(defn .breakall
  "Sets breakpoints on all instructions in the current function"
  [&opt n]
  (def fun (.fn n))
  (def bytecode (.bytecode n))
  (forv i 0 (length bytecode)
    (debug/fbreak fun i))
  (eprint "set " (length bytecode) " breakpoints in " fun))

(defn .clearall
  "Clears all breakpoints on the current function"
  [&opt n]
  (def fun (.fn n))
  (def bytecode (.bytecode n))
  (forv i 0 (length bytecode)
    (debug/unfbreak fun i))
  (eprint "cleared " (length bytecode) " breakpoints in " fun))

(defn .source
  "Shows the source code for the function being debugged"
  [&opt n]
  (def frame (.frame n))
  (def s (frame :source))
  (def all-source (slurp s))
  (eprint "\n" all-source "\n"))

(defn .break
  "Sets breakpoint at the current pc"
  []
  (def frame (.frame))
  (def fun (frame :function))
  (def pc (frame :pc))
  (debug/fbreak fun pc)
  (eprint "set breakpoint in " fun " at pc=" pc))

(defn .clear
  "Clears the current breakpoint"
  []
  (def frame (.frame))
  (def fun (frame :function))
  (def pc (frame :pc))
  (debug/unfbreak fun pc)
  (eprint "cleared breakpoint in " fun " at pc=" pc))

(defn .continue
  "Resumes execution to the next breakpoint"
  []
  (resume (dyn :fiber) :continue))

(defn .step
  "Executes one VM instruction"
  []
  (resume (dyn :fiber) :step))

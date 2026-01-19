(local {: autoload} (require :conjure.nfnl.module))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))
(local request (autoload :grapple.client.request))
(local str (autoload :conjure.nfnl.string))
(local log (autoload :grapple.client.log))
(local ui (autoload :grapple.client.ui))

;; Tab-based debugger state
(var debugger-state nil)

(fn create-debugger-buffers []
  "Creates fiber state, bytecode, source, and input buffers"
  (let [fiber-state-buf (vim.api.nvim_create_buf false true)
        bytecode-buf (vim.api.nvim_create_buf false true)
        source-buf (vim.api.nvim_create_buf false true)
        input-buf (vim.api.nvim_create_buf false true)]
    ; Set buffer options
    (vim.api.nvim_buf_set_option fiber-state-buf :buftype "nofile")
    (vim.api.nvim_buf_set_option fiber-state-buf :bufhidden "hide")
    (vim.api.nvim_buf_set_option fiber-state-buf :modifiable false)
    (vim.api.nvim_buf_set_option fiber-state-buf :filetype "grapple-fiber-state")

    (vim.api.nvim_buf_set_option bytecode-buf :buftype "nofile")
    (vim.api.nvim_buf_set_option bytecode-buf :bufhidden "hide")
    (vim.api.nvim_buf_set_option bytecode-buf :modifiable false)
    (vim.api.nvim_buf_set_option bytecode-buf :filetype "grapple-bytecode")

    (vim.api.nvim_buf_set_option source-buf :buftype "nofile")
    (vim.api.nvim_buf_set_option source-buf :bufhidden "hide")
    (vim.api.nvim_buf_set_option source-buf :modifiable false)
    (vim.api.nvim_buf_set_option source-buf :filetype "janet")

    (vim.api.nvim_buf_set_option input-buf :buftype "nofile")
    (vim.api.nvim_buf_set_option input-buf :bufhidden "hide")
    (vim.api.nvim_buf_set_option input-buf :modifiable true)
    (vim.api.nvim_buf_set_option input-buf :filetype "janet")
    ; Disable linting for this buffer (it's a REPL-like context with debug functions)
    (vim.api.nvim_buf_set_var input-buf :grapple_debug_input true)

    {:fiber-state-buf fiber-state-buf
     :bytecode-buf bytecode-buf
     :source-buf source-buf
     :input-buf input-buf}))

(fn create-tab-layout [bufs]
  "Creates a new tab with the debugger layout"
  ; Create new tab
  (vim.cmd "tabnew")
  (let [tab (vim.api.nvim_get_current_tabpage)
        ; Get the Conjure log buffer
        log-buf (log.buf)
        ; Start with the initial window from tabnew
        initial-win (vim.api.nvim_get_current_win)]

    ; Set up the grid layout:
    ; ┌────────────┬────────────┬────────┐
    ; │ Fiber      │ Source     │ Conjure│
    ; │ State      │ Code       │ Log    │
    ; ├────────────┼────────────┤        │
    ; │ Bytecode   │ Input      │        │
    ; │            │            │        │
    ; └────────────┴────────────┴────────┘

    ; Build layout left to right, top to bottom
    ; Start: fiber-state in initial window
    (let [fiber-state-win initial-win]
      (vim.api.nvim_win_set_buf fiber-state-win bufs.fiber-state-buf)

      ; Split vertically right → this becomes source
      (vim.cmd "vsplit")
      (vim.cmd "wincmd l")
      (let [source-win (vim.api.nvim_get_current_win)]
        (vim.api.nvim_win_set_buf source-win bufs.source-buf)

        ; Split vertically right → this becomes log
        (vim.cmd "vsplit")
        (vim.cmd "wincmd l")
        (let [log-win (vim.api.nvim_get_current_win)]
          (vim.api.nvim_win_set_buf log-win log-buf)

          ; Go back to fiber-state, split horizontally below to create bytecode
          (vim.api.nvim_set_current_win fiber-state-win)
          (vim.cmd "split")
          (vim.cmd "wincmd j")
          (let [bytecode-win (vim.api.nvim_get_current_win)]
            (vim.api.nvim_win_set_buf bytecode-win bufs.bytecode-buf)

            ; Go to source, split horizontally below to create input
            (vim.api.nvim_set_current_win source-win)
            (vim.cmd "split")
            (vim.cmd "wincmd j")
            (let [input-win (vim.api.nvim_get_current_win)]
              (vim.api.nvim_win_set_buf input-win bufs.input-buf)

              {:tab tab
               :fiber-state-win fiber-state-win
               :bytecode-win bytecode-win
               :source-win source-win
               :input-win input-win
               :log-win log-win})))))))

(fn close-debugger-ui []
  "Closes the debugger tab and cleans up"
  (when debugger-state
    ; Close the tab (this will close all windows in it)
    (when (and debugger-state.tab (vim.api.nvim_tabpage_is_valid debugger-state.tab))
      (let [current-tab (vim.api.nvim_get_current_tabpage)]
        ; Switch to the debug tab before closing it
        (when (not= current-tab debugger-state.tab)
          (vim.cmd (.. "tabn " (vim.api.nvim_tabpage_get_number debugger-state.tab))))
        (vim.cmd "tabclose")))
    ; Manually delete buffers
    (each [_ buf-key (ipairs [:fiber-state-buf :bytecode-buf :source-buf :input-buf])]
      (let [buf (. debugger-state buf-key)]
        (when (and buf (vim.api.nvim_buf_is_valid buf))
          (pcall vim.api.nvim_buf_delete buf {:force true}))))
    (set debugger-state nil)))

(fn set-buffer-content [buf lines]
  "Sets the content of a buffer (for readonly buffers)"
  (vim.api.nvim_buf_set_option buf :modifiable true)
  (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
  (vim.api.nvim_buf_set_option buf :modifiable false))

(fn format-fiber-state [fiber-state stack]
  "Formats fiber state (metadata + stack frames) for display"
  (let [lines []]
    ; Add fiber state metadata
    (when fiber-state
      (table.insert lines "Fiber State")
      (table.insert lines "-----------")
      (each [_ line (ipairs (vim.split fiber-state "\n" {:plain true}))]
        (table.insert lines line))
      (table.insert lines ""))
    ; Add stack frames
    (if (and stack (> (length stack) 0))
      (do
        (table.insert lines "Stack Frames")
        (table.insert lines "------------")
        (each [i frame (ipairs stack)]
          (let [name (or (. frame :name) "<anonymous>")
                path (or (. frame :path) "?")
                line (or (. frame :line) "?")
                pc (or (. frame :pc) "?")
                tail (if (. frame :tail) " [tail]" "")]
            (table.insert lines (.. "Frame " (- i 1) ": " name))
            (table.insert lines (.. "  " "path: " path))
            (table.insert lines (.. "  " "line: " line))
            (table.insert lines (.. "  " "pc: " pc))
            (when (not (= "" tail))
              (table.insert lines (.. "  " "tail?: " "true"))))))
      (table.insert lines "No stack frames available"))
    lines))

(fn format-source [stack]
  "Formats source code from current frame"
  (if (and stack (> (length stack) 0))
    (let [frame (. stack 1)
          path (or (. frame :path) nil)]
      (if path
        ; Try to read the source file using Neovim's API
        (let [(ok? lines) (pcall vim.fn.readfile path)]
          (if ok?
            lines
            [(.. "Could not read file: " path)]))
        ["No source file available"]))
    ["No stack frames available"]))

(fn format-bytecode [asm]
  "Formats bytecode for display"
  (if asm
    ; asm is now a pre-formatted string from the server's ppasm function
    (let [lines []]
      (table.insert lines "Instructions")
      (table.insert lines "------------")
      (each [_ line (ipairs (vim.split asm "\n" {:plain true}))]
        (table.insert lines line))
      lines)
    ["No bytecode available"]))

(fn update-fiber-state-window [fiber-state stack]
  "Updates the fiber state window"
  (when debugger-state
    (let [lines (format-fiber-state fiber-state stack)]
      (set-buffer-content debugger-state.fiber-state-buf lines))))

(fn update-source-window [stack]
  "Updates the source window to show the file being debugged"
  (when debugger-state
    (when (and stack (> (length stack) 0))
      (let [frame (. stack 1)
            path (. frame :path)
            line (. frame :line)]
        (when path
          ; Get or create buffer for the source file
          (let [bufnr (vim.fn.bufnr path)]
            (if (= bufnr -1)
              ; Buffer doesn't exist, create and load it
              (let [new-buf (vim.fn.bufadd path)]
                (vim.fn.bufload new-buf)
                (vim.api.nvim_win_set_buf debugger-state.source-win new-buf))
              ; Buffer exists, use it
              (vim.api.nvim_win_set_buf debugger-state.source-win bufnr)))
          ; Set cursor to the current line
          (when (and line (> line 0))
            (when (and debugger-state.source-win
                       (vim.api.nvim_win_is_valid debugger-state.source-win))
              (pcall vim.api.nvim_win_set_cursor debugger-state.source-win [line 0]))))))))

(fn update-bytecode-window [asm]
  "Updates the bytecode window"
  (when debugger-state
    (let [lines (format-bytecode asm)]
      (set-buffer-content debugger-state.bytecode-buf lines))))

(fn send-debug-command [code]
  "Sends a debug command via env.dbg"
  (when debugger-state
    (let [conn (state.get :conn)
          req debugger-state.req]
      (if (not conn)
        (log.append :error ["Not connected to server"])
        (if (not req)
          (log.append :error ["No active debug session"])
          (request.env-dbg conn
            {:code code
             :req req}))))))

(fn continue-execution []
  "Continues execution by sending (.continue) command"
  (send-debug-command "(.continue)")
  (ui.hide-debug-indicators))

(fn step-execution []
  "Steps execution by sending (.step) command"
  (send-debug-command "(.step)")
  (ui.hide-debug-indicators))

(fn setup-buffer-keymaps [bufs]
  "Sets up keymaps for debugger buffers"
  ; Helper to set keymaps on multiple buffers
  (fn set-on-all [key callback]
    (each [_ buf (pairs bufs)]
      (when (vim.api.nvim_buf_is_valid buf)
        (let [opts {:buffer buf :noremap true :silent true}]
          (vim.keymap.set :n key callback opts)))))

  ; Debug control keybindings
  (set-on-all "<localleader>dc" continue-execution)
  (set-on-all "<localleader>ds" step-execution))

(fn open-debugger-ui [stack fiber-state bytecode req]
  "Opens the tab-based debugger UI with stack and fiber state information"
  ; Save input buffer content and cursor position if it exists
  (let [saved-input-content
        (when (and debugger-state
                   debugger-state.input-buf
                   (vim.api.nvim_buf_is_valid debugger-state.input-buf))
          (vim.api.nvim_buf_get_lines debugger-state.input-buf 0 -1 false))
        saved-cursor
        (when (and debugger-state
                   debugger-state.input-win
                   (vim.api.nvim_win_is_valid debugger-state.input-win)
                   (= (vim.api.nvim_get_current_win) debugger-state.input-win))
          (vim.api.nvim_win_get_cursor debugger-state.input-win))]

    ; Close any existing UI first
    (close-debugger-ui)

    ; Create buffers
    (let [bufs (create-debugger-buffers)
          ; Create tab layout
          layout (create-tab-layout bufs)]

      ; Store state
      (set debugger-state
        {:tab layout.tab
         :fiber-state-buf bufs.fiber-state-buf
         :bytecode-buf bufs.bytecode-buf
         :source-buf bufs.source-buf
         :input-buf bufs.input-buf
         :fiber-state-win layout.fiber-state-win
         :bytecode-win layout.bytecode-win
         :source-win layout.source-win
         :input-win layout.input-win
         :log-win layout.log-win
         :req req
         :stack stack
         :fiber-state fiber-state
         :bytecode bytecode})

      ; Set window options
      (vim.api.nvim_win_set_option layout.fiber-state-win :wrap false)
      (vim.api.nvim_win_set_option layout.fiber-state-win :number false)
      (vim.api.nvim_win_set_option layout.fiber-state-win :relativenumber false)
      (vim.api.nvim_win_set_option layout.fiber-state-win :signcolumn "no")
      (vim.api.nvim_win_set_option layout.bytecode-win :wrap false)
      (vim.api.nvim_win_set_option layout.bytecode-win :number false)
      (vim.api.nvim_win_set_option layout.bytecode-win :relativenumber false)
      (vim.api.nvim_win_set_option layout.bytecode-win :signcolumn "no")
      (vim.api.nvim_win_set_option layout.source-win :wrap false)
      (vim.api.nvim_win_set_option layout.input-win :wrap false)

      ; Populate buffers with initial data
      (update-fiber-state-window fiber-state stack)
      (update-source-window stack)
      (update-bytecode-window bytecode)

      ; Restore input buffer content if we saved it, otherwise add help text
      (if saved-input-content
        (vim.api.nvim_buf_set_lines bufs.input-buf 0 -1 false saved-input-content)
        ; Add helpful comments when buffer is first created
        (vim.api.nvim_buf_set_lines bufs.input-buf 0 -1 false
          ["# Debugger Input"
           "# --------------"
           "# Expressions evaluated by Conjure in this buffer are evaluated"
           "# in the debugging environment."
           "#"
           "# Debug commands:"
           "#   (.continue)   - Continue execution"
           "#   (.ppasm)      - Pretty print disassembly"
           "#   (.step)       - Step to next instruction"
           "#"
           "# Keybindings:"
           "#   <localleader>dc - Continue"
           "#   <localleader>ds - Step"
           ""
           ""]))

      ; Set up keymaps (after buffers are populated and in windows)
      (setup-buffer-keymaps bufs)

      ; Log that debugger is open
      ; (log.append :info ["Debugger opened"])

      ; Focus the input window
      (vim.api.nvim_set_current_win layout.input-win)
      ; Restore cursor position if we were in input buffer before, otherwise go to end
      (if saved-cursor
        (vim.api.nvim_win_set_cursor layout.input-win saved-cursor)
        ; Position cursor at end of buffer (after help text) on first open
        (let [line-count (vim.api.nvim_buf_line_count bufs.input-buf)]
          (vim.api.nvim_win_set_cursor layout.input-win [line-count 0])))

      debugger-state)))

(fn handle-signal [resp]
  "Handles debug signal responses"
  (let [stack (. resp "janet/stack")
        fiber-state (. resp "janet/fiber-state")
        bytecode (. resp "janet/bytecode")
        req (. resp "req")
        file-path (. resp "janet/path")
        line (. resp "janet/line")]
    (log.append :info ["Paused evaluation"])
    ; Clear old debug indicators before showing new ones
    (ui.hide-debug-indicators)
    ; Show visual debug indicators at new position
    (when (and file-path line)
      (let [bufnr (vim.fn.bufnr file-path)]
        (when (not= bufnr -1)
          (ui.show-debug-indicators bufnr file-path line))))
    ; Open the debugger UI with stack, fiber state, and bytecode data
    (open-debugger-ui stack fiber-state bytecode req)))

(fn is-input-buffer? [bufnr]
  "Checks if the given buffer is the debugger input buffer"
  (and debugger-state (= bufnr debugger-state.input-buf)))

(fn get-debug-req []
  "Returns the current debug request ID for env.dbg operations"
  (when debugger-state
    debugger-state.req))

{: continue-execution
 : step-execution
 : handle-signal
 : is-input-buffer?
 : get-debug-req}

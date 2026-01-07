(local {: autoload} (require :conjure.nfnl.module))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))

(fn init-breakpoint-signs []
  (vim.fn.sign_define "GrappleBreakpoint"
    {:text "●"
     :texthl "DiagnosticInfo"
     :linehl ""
     :numhl ""}))

(fn add-breakpoint-sign [bufnr file-path line]
  (let [sign-id (vim.fn.sign_place 0 "grapple_breakpoints" "GrappleBreakpoint" bufnr {:lnum line})
        bp-key (.. file-path ":" line)
        breakpoints (state.get :breakpoints)]
    (n.assoc breakpoints bp-key {:bufnr bufnr :line line :sign-id sign-id})
    sign-id))

(fn remove-breakpoint-sign [file-path line]
  (let [bp-key (.. file-path ":" line)
        breakpoints (state.get :breakpoints)
        bp-data (. breakpoints bp-key)]
    (when bp-data
      (vim.fn.sign_unplace "grapple_breakpoints" {:id bp-data.sign-id :buffer bp-data.bufnr})
      (n.assoc breakpoints bp-key nil))))

(fn clear-breakpoint-signs []
  (let [breakpoints (state.get :breakpoints)]
    (each [bp-key bp-data (pairs breakpoints)]
      (vim.fn.sign_unplace "grapple_breakpoints" {:id bp-data.sign-id :buffer bp-data.bufnr}))
    (n.assoc (state.get) :breakpoints {})))

(fn init-debug-sign []
  (vim.fn.sign_define "GrappleDebugPosition"
    {:text "→"
     :texthl "DiagnosticWarn"
     :linehl ""
     :numhl ""}))

(fn show-debug-indicators [bufnr file-path line]
  ; Place the debug position sign
  (let [sign-id (vim.fn.sign_place 0 "grapple_debug" "GrappleDebugPosition" bufnr {:lnum line})]
    (n.assoc (state.get) :debug-position {:bufnr bufnr :file-path file-path :line line :sign-id sign-id}))
  ; Save original SignColumn highlight and change it to debug color
  (let [original-hl (vim.api.nvim_get_hl 0 {:name "SignColumn"})]
    (n.assoc (state.get) :original-signcol-hl original-hl)
    (vim.api.nvim_set_hl 0 "SignColumn" {:bg "#3e2723"})))  ; Dark amber/orange background

(fn hide-debug-indicators []
  ; Remove the debug position sign
  (let [debug-pos (state.get :debug-position)]
    (when debug-pos
      (vim.fn.sign_unplace "grapple_debug" {:id debug-pos.sign-id :buffer debug-pos.bufnr})
      (n.assoc (state.get) :debug-position nil)))
  ; Restore original SignColumn highlight
  (let [original-hl (state.get :original-signcol-hl)]
    (when original-hl
      (vim.api.nvim_set_hl 0 "SignColumn" original-hl)
      (n.assoc (state.get) :original-signcol-hl nil))))

{: init-breakpoint-signs
 : add-breakpoint-sign
 : remove-breakpoint-sign
 : clear-breakpoint-signs
 : init-debug-sign
 : show-debug-indicators
 : hide-debug-indicators}

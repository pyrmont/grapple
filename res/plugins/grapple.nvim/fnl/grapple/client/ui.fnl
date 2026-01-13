(local {: autoload} (require :conjure.nfnl.module))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))

(fn init-breakpoint-signs []
  (vim.fn.sign_define "GrappleBreakpoint"
    {:text "●"
     :texthl "DiagnosticInfo"
     :linehl ""
     :numhl ""}))

(fn add-breakpoint-sign [bufnr file-path line bp-id]
  (let [sign-id (vim.fn.sign_place 0 "grapple_breakpoints" "GrappleBreakpoint" bufnr {:lnum line})
        breakpoints (state.get :breakpoints)]
    (n.assoc breakpoints sign-id {:bufnr bufnr :file-path file-path :line line :bp-id bp-id})
    sign-id))

(fn get-breakpoint-at-line [bufnr line]
  "Query signs at the given line and return breakpoint data if found"
  (let [signs (vim.fn.sign_getplaced bufnr {:lnum line :group "grapple_breakpoints"})]
    (when (and signs (> (length signs) 0))
      (let [buf-signs (. signs 1)
            sign-list (. buf-signs :signs)]
        (when (and sign-list (> (length sign-list) 0))
          (let [sign (. sign-list 1)
                sign-id (. sign :id)
                breakpoints (state.get :breakpoints)]
            (. breakpoints sign-id)))))))

(fn get-sign-current-line [sign-id]
  "Get the current line number where this sign is placed"
  (let [breakpoints (state.get :breakpoints)
        bp-data (. breakpoints sign-id)]
    (when bp-data
      ; sign_getplaced returns [{bufnr: X, signs: [{id: Y, lnum: Z}]}] even for single sign
      (let [result (vim.fn.sign_getplaced bp-data.bufnr {:id sign-id :group "grapple_breakpoints"})]
        (when (and result (> (length result) 0))
          (let [buf-info (. result 1)
                signs (. buf-info :signs)]
            (when (and signs (> (length signs) 0))
              (let [sign (. signs 1)]
                (. sign :lnum)))))))))

(fn remove-breakpoint-sign [sign-id]
  (let [breakpoints (state.get :breakpoints)
        bp-data (. breakpoints sign-id)]
    (when bp-data
      (vim.fn.sign_unplace "grapple_breakpoints" {:id sign-id :buffer bp-data.bufnr})
      (n.assoc breakpoints sign-id nil))))

(fn clear-breakpoint-signs []
  (let [breakpoints (state.get :breakpoints)]
    (each [sign-id bp-data (pairs breakpoints)]
      (vim.fn.sign_unplace "grapple_breakpoints" {:id sign-id :buffer bp-data.bufnr}))
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
 : get-breakpoint-at-line
 : get-sign-current-line
 : remove-breakpoint-sign
 : clear-breakpoint-signs
 : init-debug-sign
 : show-debug-indicators
 : hide-debug-indicators}

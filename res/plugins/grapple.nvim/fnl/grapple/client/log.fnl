(local {: autoload} (require :nfnl.module))
(local client (autoload :conjure.client))
(local log (autoload :conjure.log))
(local n (autoload :nfnl.core))
(local state (autoload :grapple.client.state))
(local str (autoload :conjure.nfnl.string))

(local info-header   "======= info =======")
(local error-header  "====== error =======")
(local input-header  "====== input =======")
(local result-header "====== result ======")
(local stdout-header "====== stdout ======")
(local stderr-header "====== stderr ======")

; Namespace for extmarks
(local ns (vim.api.nvim_create_namespace "grapple-log"))

; Apply highlight to a range of lines
(fn highlight-lines [buf start-line end-line hl-group]
  (for [line start-line (- end-line 1)]
    (vim.api.nvim_buf_add_highlight buf ns hl-group line 0 -1)))

(fn log-buf-name []
  (str.join ["conjure-log-" (vim.fn.getpid) (client.get :buf-suffix)]))

(fn append [sec lines opts]
  (when (not (n.empty? lines))
    (let [buf (vim.fn.bufnr (log-buf-name))
          curr-sec (state.get :log-sec)]
      ; print heading if different to current section
      (when (not= curr-sec sec)
        (n.assoc (state.get) :log-sec sec)
        (let [header (case sec
                       :info info-header
                       :error error-header
                       :input input-header
                       :result result-header
                       :stdout stdout-header
                       :stderr stderr-header)]
          (log.append [header])
          (let [line-count (vim.api.nvim_buf_line_count buf)]
            (highlight-lines buf (- line-count 1) line-count "Comment"))))
      (let [start-line (vim.api.nvim_buf_line_count buf)]
        (log.append lines opts)
        (when start-line
          (let [end-line (vim.api.nvim_buf_line_count buf)]
            (case sec
              :info (highlight-lines buf start-line end-line "Title")
              :error (highlight-lines buf start-line end-line "ErrorMsg")
              :stdout (highlight-lines buf start-line end-line "String")
              :stderr (highlight-lines buf start-line end-line "WarningMsg")
              ; for :input and :result, do nothing, let Janet syntax apply
              _ nil)))))))

(fn buf []
  (log.last-line)
  (vim.fn.bufnr (log-buf-name)))

{: append
 : buf}

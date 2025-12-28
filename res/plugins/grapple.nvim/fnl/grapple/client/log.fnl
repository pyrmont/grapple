(local {: autoload} (require :conjure.nfnl.module))
(local client (autoload :conjure.client))
(local log (autoload :conjure.log))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))
(local str (autoload :conjure.nfnl.string))

(local info-header   "======= info =======")
(local error-header  "====== error =======")
(local input-header  "====== input =======")
(local note-header   "======= note =======")
(local result-header "====== result ======")
(local stdout-header "====== stdout ======")
(local stderr-header "====== stderr ======")

; Namespace for extmarks
(local ns (vim.api.nvim_create_namespace "grapple-log"))

; Apply highlight to a range of lines
(fn highlight-lines [buf start end hl-group]
  (vim.api.nvim_buf_set_extmark buf ns start 0 {:end_row end
                                                :hl_group hl-group
                                                :priority 200}))

(fn log-buf-name []
  (str.join ["conjure-log-" (vim.fn.getpid) (client.get :buf-suffix)]))

(fn append [sec lines opts]
  (when (not (n.empty? lines))
    (let [buf (vim.fn.bufnr (log-buf-name))
          curr-sec (state.get :log-sec)
          add-heading? (not= curr-sec sec)
          start-line (vim.api.nvim_buf_line_count buf)
          [header hl-group] (case sec
                              :info   [info-header "Title"]
                              :error  [error-header "ErrorMsg"]
                              :input  [input-header nil]
                              :note   [note-header "Special"]
                              :stdout [stdout-header "String"]
                              :stderr [stderr-header "WarningMsg"]
                              _       [result-header nil])]
      ; append heading if different to current section
      (when add-heading?
        (n.assoc (state.get) :log-sec sec)
        (log.immediate-append [header])
        (highlight-lines buf start-line (+ start-line 1) "Comment"))
      ; append the lines
      (log.immediate-append lines opts)
      (when hl-group
        (highlight-lines buf
                         (+ start-line (if add-heading? 1 0))
                         (vim.api.nvim_buf_line_count buf)
                         hl-group)))))

(fn buf []
  (log.last-line)
  (vim.fn.bufnr (log-buf-name)))

{: append
 : buf}

(local {: autoload} (require :conjure.nfnl.module))
(local client (autoload :conjure.client))

(local get
  (client.new-state
    (fn []
      {:conn nil
       :server-pid nil
       :server-port nil
       :token nil
       :server-ready false
       :breakpoints {}
       :debug-position nil
       :original-signcol-hl nil
       :result-counter 0
       :val-to-id {}
       :id-to-val {}})))

{: get}

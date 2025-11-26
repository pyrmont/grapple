(local {: autoload} (require :conjure.nfnl.module))
(local client (autoload :conjure.client))

(local get
  (client.new-state
    (fn []
      {:conn nil})))

{: get}

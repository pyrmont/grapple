(local {: autoload} (require :nfnl.module))
(local log (autoload :conjure.log))

(fn append [lines opts]
  (log/append "grapple" lines opts))

{: append}

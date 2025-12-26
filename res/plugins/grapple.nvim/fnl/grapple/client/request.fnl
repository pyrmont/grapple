(local {: autoload} (require :conjure.nfnl.module))
(local log (autoload :grapple.client.log))
(local n (autoload :conjure.nfnl.core))

(fn sess-new [conn opts]
  (conn.send {:op "sess.new"}
             opts))

(fn sess-end [conn opts]
  (conn.send {:op "sess.end"}
             opts))

(fn sess-list [conn opts]
  (conn.send {:op "sess.list"}
             opts))

(fn serv-info [conn opts]
  (conn.send {:op "serv.info"}
             opts))

(fn serv-stop [conn opts]
  (conn.send {:op "serv.stop"}
             opts))

(fn serv-rest [conn opts]
  (log.append :error ["serv.rest is not supported"]))

(fn env-eval [conn opts]
  (log.append :input [opts.code])
  (conn.send {:op "env.eval"
              :ns opts.file-path
              :code opts.code
              :col (n.get-in opts.range [:start 2] 1)
              :line (n.get-in opts.range [:start 1] 1)}
             opts))

(fn env-load [conn opts]
  (conn.send {:op "env.load"
              :path opts.file-path}
             opts))

(fn env-stop [conn opts]
  (log.append :error ["env.stop is not supported"]))

(fn env-doc [conn opts]
  (conn.send {:op "env.doc"
              :ns opts.file-path
              :sym opts.code}
             opts))

(fn env-cmpl [conn opts]
  (conn.send {:op "env.cmpl"
              :ns opts.file-path
              :sym opts.code}
             opts))

{: sess-new
 : sess-end
 : sess-list
 : serv-info
 : serv-stop
 : serv-rest
 : env-eval
 : env-load
 : env-stop
 : env-doc
 : env-cmpl}

(local {: autoload} (require :nfnl.module))
(local log (autoload :grapple.client.log))
(local n (autoload :nfnl.core))

(fn sess-new [conn opts]
  (conn.send {:op "sess.new"}
             opts.action))

(fn sess-end [conn opts]
  (conn.send {:op "sess.end"}
             (if opts opts.action nil)))

(fn sess-list [conn opts]
  (conn.send {:op "sess.list"}
             opts.action))

(fn serv-info [conn opts]
  (conn.send {:op "serv.info"}
             opts.action))

(fn serv-stop [conn opts]
  (conn.send {:op "serv.stop"}
             opts.action))

(fn serv-rest [conn opts]
  (log.append :error ["serv.rest is not supported"]))

(fn env-eval [conn opts]
  (log.append :input [opts.code])
  (conn.send {:op "env.eval"
              :ns opts.file-path
              :code opts.code
              :col (n.get-in opts.range [:start 2] 1)
              :line (n.get-in opts.range [:start 1] 1)}
             opts.action))

(fn env-load [conn opts]
  (conn.send {:op "env.load"
              :path opts.file-path}
             opts.action))

(fn env-stop [conn opts]
  (log.append :error ["env.stop is not supported"]))

(fn env-doc [conn opts]
  (conn.send {:op "env.doc"
              :ns opts.file-path
              :sym opts.code}
             opts.action))

(fn env-cmpl [conn opts]
  (conn.send {:op "env.cmpl"
              :ns opts.file-path
              :sym opts.code}
             opts.action))

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

(local {: autoload} (require :conjure.nfnl.module))
(local log (autoload :grapple.client.log))
(local n (autoload :conjure.nfnl.core))
(local state (autoload :grapple.client.state))

(fn sess-new [conn opts]
  (let [token (state.get :token)
        msg {:op "sess.new"}]
    (when token
      (n.assoc msg :auth token))
    (conn.send msg opts)))

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

(fn dbg-brk-add [conn opts]
  ; (log.append :debug [(.. "Setting breakpoint at " opts.file-path ":" opts.line)])
  (conn.send {:op "dbg.brk.add"
              :path opts.file-path
              :line opts.line
              :col (or opts.col 1)}
             opts))

(fn dbg-brk-rem [conn opts]
  ; (log.append :debug [(.. "Removing breakpoint at " opts.file-path ":" opts.line)])
  (conn.send {:op "dbg.brk.rem"
              :path opts.file-path
              :line opts.line}
             opts))

(fn dbg-brk-clr [conn opts]
  ; (log.append :debug ["Clearing all breakpoints..."])
  (conn.send {:op "dbg.brk.clr"}
             opts))

(fn dbg-step-cont [conn opts]
  (log.append :debug ["Continuing execution..."])
  (conn.send {:op "dbg.step.cont"}
             opts))

(fn dbg-insp-stk [conn opts]
  (log.append :debug ["Inspecting stack..."])
  (conn.send {:op "dbg.insp.stk"}
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
 : env-cmpl
 : dbg-brk-add
 : dbg-brk-rem
 : dbg-brk-clr
 : dbg-step-cont
 : dbg-insp-stk}

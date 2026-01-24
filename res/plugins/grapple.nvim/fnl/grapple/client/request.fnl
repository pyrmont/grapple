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

(fn mgmt-info [conn opts]
  (conn.send {:op "mgmt.info"}
             opts))

(fn mgmt-stop [conn opts]
  (conn.send {:op "mgmt.stop"}
             opts))

(fn mgmt-rest [conn opts]
  (log.append :error ["mgmt.rest is not supported"]))

(fn env-eval [conn opts]
  (log.append :input [opts.code])
  (conn.send {:op "env.eval"
              :ns opts.file-path
              :code opts.code
              :col (n.get-in opts.range [:start 2] 1)
              :line (n.get-in opts.range [:start 1] 1)}
             opts))

(fn env-load [conn opts]
  (log.append :info ["Loading file..."])
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

(fn brk-add [conn opts]
  (conn.send {:op "brk.add"
              :path opts.file-path
              :janet/rline opts.rline
              :janet/rcol opts.rcol
              :janet/form opts.form}
             opts))

(fn brk-rem [conn opts]
  ; (log.append :debug [(.. "Removing breakpoint with ID: " opts.bp-id)])
  (conn.send {:op "brk.rem"
              :bp-id opts.bp-id}
             opts))

(fn brk-clr [conn opts]
  ; (log.append :debug ["Clearing all breakpoints..."])
  (conn.send {:op "brk.clr"}
             opts))

(fn brk-list [conn opts]
  (conn.send {:op "brk.list"}
             opts))

(fn env-dbg [conn opts]
  (log.append :debug [opts.code])
  (conn.send {:op "env.dbg"
              :code opts.code
              :req opts.req}
             opts))

{: sess-new
 : sess-end
 : sess-list
 : mgmt-info
 : mgmt-stop
 : mgmt-rest
 : env-eval
 : env-load
 : env-stop
 : env-doc
 : env-cmpl
 : brk-add
 : brk-rem
 : brk-clr
 : brk-list
 : env-dbg}

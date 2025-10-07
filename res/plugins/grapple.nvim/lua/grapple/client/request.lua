-- [nfnl] Compiled from fnl/grapple/client/request.fnl by https://github.com/Olical/nfnl, do not edit.
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local log = autoload("grapple.client.log")
local n = autoload("nfnl.core")
local state = autoload("grapple.client.state")
local function sess_new(conn, opts)
  return conn.send({op = "sess.new"}, opts.action)
end
local function sess_end(conn, opts)
  local function _2_()
    if opts then
      return opts.action
    else
      return nil
    end
  end
  return conn.send({op = "sess.end"}, _2_())
end
local function sess_list(conn, opts)
  return conn.send({op = "sess.list"}, opts.action)
end
local function serv_info(conn, opts)
  return conn.send({op = "serv.info"}, opts.action)
end
local function serv_stop(conn, opts)
  return conn.send({op = "serv.stop"}, opts.action)
end
local function serv_rest(conn, opts)
  return conn.send({op = "serv.rest"}, opts.action)
end
local function env_eval(conn, opts)
  return conn.send({op = "env.eval", ns = opts["file-path"], code = opts.code, col = n["get-in"](opts.range, {"start", 2}, 1), line = n["get-in"](opts.range, {"start", 1}, 1)}, opts.action)
end
local function env_load(conn, opts)
  return conn.send({op = "env.load", path = opts["file-path"]}, opts.action)
end
local function env_stop(conn, opts)
  return log.append({"# env.stop is not supported"})
end
local function env_doc(conn, opts)
  return conn.send({op = "env.doc", ns = opts["file-path"], sym = opts.code}, opts.action)
end
local function env_cmpl(conn, opts)
  return conn.send({op = "env.cmpl", ns = opts["file-path"], sym = opts.code}, opts.action)
end
return {["sess-new"] = sess_new, ["sess-end"] = sess_end, ["sess-list"] = sess_list, ["serv-info"] = serv_info, ["serv-stop"] = serv_stop, ["serv-rest"] = serv_rest, ["env-eval"] = env_eval, ["env-load"] = env_load, ["env-stop"] = env_stop, ["env-doc"] = env_doc, ["env-cmpl"] = env_cmpl}

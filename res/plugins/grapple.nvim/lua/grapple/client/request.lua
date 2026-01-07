-- [nfnl] fnl/grapple/client/request.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local log = autoload("grapple.client.log")
local n = autoload("conjure.nfnl.core")
local state = autoload("grapple.client.state")
local function sess_new(conn, opts)
  local token = state.get("token")
  local msg = {op = "sess.new"}
  if token then
    n.assoc(msg, "auth", token)
  else
  end
  return conn.send(msg, opts)
end
local function sess_end(conn, opts)
  return conn.send({op = "sess.end"}, opts)
end
local function sess_list(conn, opts)
  return conn.send({op = "sess.list"}, opts)
end
local function serv_info(conn, opts)
  return conn.send({op = "serv.info"}, opts)
end
local function serv_stop(conn, opts)
  return conn.send({op = "serv.stop"}, opts)
end
local function serv_rest(conn, opts)
  return log.append("error", {"serv.rest is not supported"})
end
local function env_eval(conn, opts)
  log.append("input", {opts.code})
  return conn.send({op = "env.eval", ns = opts["file-path"], code = opts.code, col = n["get-in"](opts.range, {"start", 2}, 1), line = n["get-in"](opts.range, {"start", 1}, 1)}, opts)
end
local function env_load(conn, opts)
  return conn.send({op = "env.load", path = opts["file-path"]}, opts)
end
local function env_stop(conn, opts)
  return log.append("error", {"env.stop is not supported"})
end
local function env_doc(conn, opts)
  return conn.send({op = "env.doc", ns = opts["file-path"], sym = opts.code}, opts)
end
local function env_cmpl(conn, opts)
  return conn.send({op = "env.cmpl", ns = opts["file-path"], sym = opts.code}, opts)
end
local function dbg_brk_add(conn, opts)
  return conn.send({op = "dbg.brk.add", path = opts["file-path"], line = opts.line, col = (opts.col or 1)}, opts)
end
local function dbg_brk_rem(conn, opts)
  return conn.send({op = "dbg.brk.rem", path = opts["file-path"], line = opts.line}, opts)
end
local function dbg_brk_clr(conn, opts)
  return conn.send({op = "dbg.brk.clr"}, opts)
end
local function dbg_step_cont(conn, opts)
  log.append("debug", {"Continuing execution..."})
  return conn.send({op = "dbg.step.cont"}, opts)
end
local function dbg_insp_stk(conn, opts)
  log.append("debug", {"Inspecting stack..."})
  return conn.send({op = "dbg.insp.stk"}, opts)
end
return {["sess-new"] = sess_new, ["sess-end"] = sess_end, ["sess-list"] = sess_list, ["serv-info"] = serv_info, ["serv-stop"] = serv_stop, ["serv-rest"] = serv_rest, ["env-eval"] = env_eval, ["env-load"] = env_load, ["env-stop"] = env_stop, ["env-doc"] = env_doc, ["env-cmpl"] = env_cmpl, ["dbg-brk-add"] = dbg_brk_add, ["dbg-brk-rem"] = dbg_brk_rem, ["dbg-brk-clr"] = dbg_brk_clr, ["dbg-step-cont"] = dbg_step_cont, ["dbg-insp-stk"] = dbg_insp_stk}

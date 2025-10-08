-- [nfnl] fnl/grapple/client.fnl
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local config = autoload("conjure.config")
local handler = autoload("grapple.client.handler")
local log = autoload("grapple.client.log")
local mapping = autoload("conjure.mapping")
local n = autoload("nfnl.core")
local remote = autoload("grapple.remote")
local request = autoload("grapple.client.request")
local state = autoload("grapple.client.state")
local ts = autoload("conjure.tree-sitter")
local buf_suffix = ".janet"
local comment_prefix = "# "
local comment_node_3f = ts["lisp-comment-node?"]
local form_node_3f = ts["node-surrounded-by-form-pair-chars?"]
config.merge({client = {janet = {mrepl = {connection = {default_host = "127.0.0.1", default_port = "3737", lang = "net.inqk/janet-1.0"}}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {janet = {mrepl = {mapping = {connect = "cc", disconnect = "cd", ["start-server"] = "cs", ["stop-server"] = "cS"}}}}})
else
end
local function start_server(opts)
  local host = (opts.host or config["get-in"]({"client", "janet", "mrepl", "connection", "default_host"}))
  local port = (opts.port or config["get-in"]({"client", "janet", "mrepl", "connection", "default_port"}))
  local pid = vim.fn.jobstart({"grapple", "--host", host, "--port", port}, {detach = true})
  n.assoc(state.get(), "server-pid", pid)
  return log.append("info", {"Server started"})
end
local function with_conn_or_warn(f, opts)
  local conn = state.get("conn")
  if conn then
    return f(conn)
  else
    return log.append("info", {"No connection"})
  end
end
local function connected_3f()
  if state.get("conn") then
    return true
  else
    return false
  end
end
local function display_conn_status(status)
  local function _5_(conn)
  end
  return with_conn_or_warn(_5_)
end
local function disconnect()
  local function _6_(conn)
    request["sess-end"](conn, nil)
    conn.destroy()
    display_conn_status("disconnected")
    return n.assoc(state.get(), "conn", nil)
  end
  return with_conn_or_warn(_6_)
end
local function stop_server()
  local pid = state.get("server-pid")
  if pid then
    disconnect()
    vim.fn.jobstop(pid)
    n.assoc(state.get(), "server-pid", nil)
    return log.append("info", {"Server stopped"})
  else
    return nil
  end
end
local function connect(opts)
  local buf = log.buf()
  local opts0 = (opts or {})
  local host = (opts0.host or config["get-in"]({"client", "janet", "mrepl", "connection", "default_host"}))
  local port = (opts0.port or config["get-in"]({"client", "janet", "mrepl", "connection", "default_port"}))
  local lang = config["get-in"]({"client", "janet", "mrepl", "connection", "lang"})
  local auto_start_3f = not opts0["no-auto-start?"]
  if state.get("conn") then
    disconnect()
  else
  end
  local conn
  local function _9_(err)
    if (auto_start_3f and not opts0["retry?"]) then
      start_server(opts0)
      local function _10_()
        return connect(n.assoc(opts0, "retry?", true))
      end
      return vim.defer_fn(_10_, 1000)
    else
      display_conn_status(err)
      return disconnect()
    end
  end
  local function _12_()
    n.assoc(state.get(), "conn", conn)
    display_conn_status("connected")
    return request["sess-new"](conn, opts0)
  end
  local function _13_(err)
    if err then
      return display_conn_status(err)
    else
      return disconnect()
    end
  end
  conn = remote.connect({host = host, port = port, lang = lang, ["on-message"] = handler["handle-message"], ["on-failure"] = _9_, ["on-success"] = _12_, ["on-error"] = _13_})
  return nil
end
local function try_ensure_conn()
  if not connected_3f() then
    return connect({["silent?"] = true})
  else
    return nil
  end
end
local function eval_str(opts)
  try_ensure_conn()
  return request["env-eval"](state.get("conn"), opts)
end
local function eval_file(opts)
  try_ensure_conn()
  return request["env-load"](state.get("conn"), opts)
end
local function doc_str(opts)
  try_ensure_conn()
  return request["env-doc"](state.get("conn"), opts)
end
local function def_str(opts)
  try_ensure_conn()
  return request["env-doc"](state.get("conn"), opts)
end
local function on_filetype()
  mapping.buf("JanetDisconnect", config["get-in"]({"client", "janet", "mrepl", "mapping", "disconnect"}), disconnect, {desc = "Disconnect from the REPL"})
  local function _16_()
    return connect()
  end
  mapping.buf("JanetConnect", config["get-in"]({"client", "janet", "mrepl", "mapping", "connect"}), _16_, {desc = "Connect to a REPL"})
  return mapping.buf("JanetStop", config["get-in"]({"client", "janet", "mrepl", "mapping", "stop-server"}), stop_server, {desc = "Stop the Grapple server"})
end
local function on_load()
  return connect({})
end
local function on_exit()
  return disconnect()
end
local function modify_client_exec_fn_opts(action, f_name, opts)
  if ("doc" == action) then
    return n.assoc(opts, "passive?", true)
  elseif ("eval" == action) then
    return n.assoc(opts, "passive?", true)
  else
    return nil
  end
end
return {["buf-suffix"] = buf_suffix, ["comment-node?"] = comment_node_3f, ["comment-prefix"] = comment_prefix, ["start-server"] = start_server, ["stop-server"] = stop_server, connect = connect, disconnect = disconnect, ["def-str"] = def_str, ["doc-str"] = doc_str, ["eval-file"] = eval_file, ["eval-str"] = eval_str, ["form-node?"] = form_node_3f, ["modify-client-exec-fn-opts"] = modify_client_exec_fn_opts, ["on-exit"] = on_exit, ["on-filetype"] = on_filetype, ["on-load"] = on_load}

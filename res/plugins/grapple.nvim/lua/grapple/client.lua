-- [nfnl] fnl/grapple/client.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local config = autoload("conjure.config")
local handler = autoload("grapple.client.handler")
local log = autoload("grapple.client.log")
local mapping = autoload("conjure.mapping")
local n = autoload("conjure.nfnl.core")
local remote = autoload("grapple.remote")
local request = autoload("grapple.client.request")
local state = autoload("grapple.client.state")
local ts = autoload("conjure.tree-sitter")
local buf_suffix = ".janet"
local comment_prefix = "# "
local comment_node_3f = ts["lisp-comment-node?"]
local form_node_3f = ts["node-surrounded-by-form-pair-chars?"]
config.merge({client = {janet = {mrepl = {connection = {default_host = "127.0.0.1", default_port = "3737", lang = "net.inqk/janet-1.0", ["auto-repl"] = {enabled = true}}}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {janet = {mrepl = {mapping = {connect = "cc", disconnect = "cd", ["start-server"] = "cs", ["stop-server"] = "cS"}}}}})
else
end
local function process_alive_3f(job_id)
  local result = vim.fn.jobwait({job_id}, 0)
  return (-1 == result[1])
end
local function start_server(opts)
  local buf = log.buf()
  local existing_pid = state.get("server-pid")
  if (existing_pid and process_alive_3f(existing_pid)) then
    return log.append("info", {"Server is already running"})
  else
    local host = (opts.host or config["get-in"]({"client", "janet", "mrepl", "connection", "default_host"}))
    local initial_port = (opts.port or config["get-in"]({"client", "janet", "mrepl", "connection", "default_port"}))
    local max_attempts = 5
    local grapple_cmd = vim.fn.exepath("grapple")
    log.append("info", {("Starting server on port " .. initial_port .. "...")})
    local function try_port(attempt, current_port)
      if (attempt >= max_attempts) then
        return log.append("error", {("Failed to start server after " .. max_attempts .. " attempts")})
      else
        local job_id = vim.fn.jobstart({grapple_cmd, "--host", host, "--port", tostring(current_port)})
        local function _3_()
          if process_alive_3f(job_id) then
            n.assoc(state.get(), "server-pid", job_id)
            n.assoc(state.get(), "server-port", tostring(current_port))
            return log.append("info", {("Server started successfully on port " .. current_port)})
          else
            log.append("info", {("Port " .. current_port .. " unavailable, trying " .. (current_port + 1) .. "...")})
            return try_port((attempt + 1), (current_port + 1))
          end
        end
        return vim.defer_fn(_3_, 1000)
      end
    end
    return try_port(0, tonumber(initial_port))
  end
end
local function with_conn_or_warn(f, opts)
  local conn = state.get("conn")
  if conn then
    return f(conn)
  else
    return log.append("info", {"Not connected to server"})
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
  local buf = log.buf()
  if (status == "connected") then
    return nil
  elseif (status == "disconnected") then
    return log.append("info", {"Disconnected from server"})
  else
    local _ = status
    if (string.find(tostring(status), "connection refused") or string.find(tostring(status), "ECONNREFUSED")) then
      return log.append("error", {"No server running, start with <localleader>cs"})
    else
      return log.append("error", {tostring(status)})
    end
  end
end
local function disconnect()
  local function _11_(conn)
    request["sess-end"](conn, nil)
    conn.destroy()
    n.assoc(state.get(), "conn", nil)
    return log.append("info", {"Disconnected from server"})
  end
  return with_conn_or_warn(_11_)
end
local function stop_server()
  local buf = log.buf()
  local pid = state.get("server-pid")
  if pid then
    if state.get("conn") then
      disconnect()
    else
    end
    vim.fn.jobstop(pid)
    n.assoc(state.get(), "server-pid", nil)
    return log.append("info", {"Server stopped"})
  else
    return log.append("info", {"No server running"})
  end
end
local function connect(opts)
  local buf = log.buf()
  local opts0 = (opts or {})
  local host = (opts0.host or config["get-in"]({"client", "janet", "mrepl", "connection", "default_host"}))
  local port = (opts0.port or state.get("server-port") or config["get-in"]({"client", "janet", "mrepl", "connection", "default_port"}))
  local lang = config["get-in"]({"client", "janet", "mrepl", "connection", "lang"})
  local auto_start_3f
  if n["nil?"](opts0["no-auto-start?"]) then
    auto_start_3f = config["get-in"]({"client", "janet", "mrepl", "connection", "auto-repl", "enabled"})
  else
    auto_start_3f = not opts0["no-auto-start?"]
  end
  log.append("info", {("Attempting to connect to " .. host .. ":" .. port .. "...")})
  if state.get("conn") then
    disconnect()
  else
  end
  local conn
  local function _16_(err)
    if (auto_start_3f and not opts0["retry?"]) then
      start_server(opts0)
      local function _17_()
        return connect(n.assoc(opts0, "retry?", true))
      end
      return vim.defer_fn(_17_, 1000)
    else
      return display_conn_status(err)
    end
  end
  local function _19_()
    n.assoc(state.get(), "conn", conn)
    display_conn_status("connected")
    return request["sess-new"](conn, opts0)
  end
  local function _20_(err)
    if err then
      return display_conn_status(err)
    else
      return disconnect()
    end
  end
  conn = remote.connect({host = host, port = port, lang = lang, ["on-message"] = handler["handle-message"], ["on-failure"] = _16_, ["on-success"] = _19_, ["on-error"] = _20_})
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
  local function _23_()
    return connect()
  end
  mapping.buf("JanetConnect", config["get-in"]({"client", "janet", "mrepl", "mapping", "connect"}), _23_, {desc = "Connect to a REPL"})
  local function _24_()
    return start_server({})
  end
  mapping.buf("JanetStart", config["get-in"]({"client", "janet", "mrepl", "mapping", "start-server"}), _24_, {desc = "Start the Grapple server"})
  return mapping.buf("JanetStop", config["get-in"]({"client", "janet", "mrepl", "mapping", "stop-server"}), stop_server, {desc = "Stop the Grapple server"})
end
local function on_load()
  return nil
end
local function on_exit()
  return disconnect()
end
local function modify_client_exec_fn_opts(action, f_name, opts)
  if ("doc" == action) then
    n.assoc(opts, "passive?", true)
  elseif ("eval" == action) then
    n.assoc(opts, "passive?", true)
  else
  end
  if (opts["on-result"] and opts["suppress-hud?"]) then
    local on_result = opts["on-result"]
    local function _26_(result)
      return on_result(("=> " .. result))
    end
    return n.assoc(opts, "on-result", _26_)
  else
    return opts
  end
end
return {["buf-suffix"] = buf_suffix, ["comment-node?"] = comment_node_3f, ["comment-prefix"] = comment_prefix, ["start-server"] = start_server, ["stop-server"] = stop_server, connect = connect, disconnect = disconnect, ["def-str"] = def_str, ["doc-str"] = doc_str, ["eval-file"] = eval_file, ["eval-str"] = eval_str, ["form-node?"] = form_node_3f, ["modify-client-exec-fn-opts"] = modify_client_exec_fn_opts, ["on-exit"] = on_exit, ["on-filetype"] = on_filetype, ["on-load"] = on_load}

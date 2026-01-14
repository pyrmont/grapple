-- [nfnl] fnl/grapple/client.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local config = autoload("conjure.config")
local extract = autoload("conjure.extract")
local handler = autoload("grapple.client.handler")
local log = autoload("grapple.client.log")
local mapping = autoload("conjure.mapping")
local n = autoload("conjure.nfnl.core")
local remote = autoload("grapple.remote")
local request = autoload("grapple.client.request")
local state = autoload("grapple.client.state")
local ts = autoload("conjure.tree-sitter")
local ui = autoload("grapple.client.ui")
local buf_suffix = ".janet"
local comment_prefix = "# "
local comment_node_3f = ts["lisp-comment-node?"]
local form_node_3f = ts["node-surrounded-by-form-pair-chars?"]
config.merge({client = {janet = {mrepl = {connection = {default_host = "127.0.0.1", default_port = "3737", lang = "net.inqk/janet-1.0", ["auto-repl"] = {enabled = true}}}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {janet = {mrepl = {mapping = {connect = "cc", disconnect = "cd", ["start-server"] = "cs", ["stop-server"] = "cS", ["add-breakpoint"] = "dba", ["remove-breakpoint"] = "dbr", ["clear-breakpoints"] = "dbc", continue = "dsc", ["inspect-stack"] = "dis"}}}}})
else
end
local function process_alive_3f(job_id)
  local result = vim.fn.jobwait({job_id}, 0)
  return (-1 == result[1])
end
local function generate_token()
  local f = io.open("/dev/urandom", "rb")
  local bytes = f:read(16)
  local _ = f:close()
  local hex_chars = "0123456789abcdef"
  local token
  local function _3_(acc, byte)
    local b = string.byte(byte)
    local high = bit.rshift(b, 4)
    local low = bit.band(b, 15)
    return (acc .. string.sub(hex_chars, (high + 1), (high + 1)) .. string.sub(hex_chars, (low + 1), (low + 1)))
  end
  token = n.reduce(_3_, "", vim.split(bytes, "", true))
  return token
end
local function wait_for_server_ready(on_ready, on_timeout)
  local function poll(attempt)
    if state.get("server-ready") then
      return on_ready()
    else
      if (attempt < 50) then
        local function _4_()
          return poll((attempt + 1))
        end
        return vim.defer_fn(_4_, 100)
      else
        return on_timeout()
      end
    end
  end
  return poll(0)
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
    local token = generate_token()
    local grapple_path = (vim.env.GRAPPLE_PATH or vim.fn.exepath("grapple"))
    local base_cmd = vim.split(grapple_path, " ")
    n.assoc(state.get(), "token", token)
    n.assoc(state.get(), "server-ready", false)
    log.append("info", {("Starting server on port " .. initial_port .. "...")})
    local function try_port(attempt, current_port)
      if (attempt >= max_attempts) then
        return log.append("error", {("Failed to start server after " .. max_attempts .. " attempts")})
      else
        local full_cmd = vim.list_extend(vim.fn.copy(base_cmd), {"--host", host, "--port", tostring(current_port), "--token", token})
        local job_id = vim.fn.jobstart(full_cmd)
        n.assoc(state.get(), "server-pid", job_id)
        n.assoc(state.get(), "server-port", tostring(current_port))
        local function _7_()
          if process_alive_3f(job_id) then
            log.append("info", {("Server started successfully on port " .. current_port)})
            return n.assoc(state.get(), "server-ready", true)
          else
            n.assoc(state.get(), "server-pid", nil)
            log.append("info", {("Port " .. current_port .. " unavailable, trying " .. (current_port + 1) .. "...")})
            return try_port((attempt + 1), (current_port + 1))
          end
        end
        return vim.defer_fn(_7_, 1000)
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
    return log.append("error", {"Not connected to server"})
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
  local function _15_(conn)
    request["sess-end"](conn, nil)
    conn.destroy()
    n.assoc(state.get(), "conn", nil)
    return log.append("info", {"Disconnected from server"})
  end
  return with_conn_or_warn(_15_)
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
    n.assoc(state.get(), "token", nil)
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
  local function _20_(err)
    if (auto_start_3f and not opts0["retry?"]) then
      start_server(opts0)
      local function _21_()
        return connect(n.assoc(opts0, "retry?", true))
      end
      local function _22_()
        return log.append("error", {"Server failed to start in time"})
      end
      return wait_for_server_ready(_21_, _22_)
    else
      return display_conn_status(err)
    end
  end
  local function _24_()
    n.assoc(state.get(), "conn", conn)
    display_conn_status("connected")
    local function _25_()
      n.assoc(state.get(), "token", nil)
      do
        local old_conn = state.get("conn")
        if old_conn then
          old_conn.destroy()
          n.assoc(state.get(), "conn", nil)
        else
        end
      end
      if (auto_start_3f and not opts0["retry?"]) then
        log.append("info", {"Authentication failed, starting new server..."})
        start_server(n.assoc(opts0, "port", tostring((tonumber(port) + 1))))
        local function _27_()
          return connect(n.assoc(opts0, "retry?", true))
        end
        local function _28_()
          return log.append("error", {"Server failed to start in time"})
        end
        return wait_for_server_ready(_27_, _28_)
      else
        return log.append("error", {"Authentication failed"})
      end
    end
    return request["sess-new"](conn, n.assoc(opts0, "on-auth-error", _25_))
  end
  local function _30_(err)
    if err then
      return display_conn_status(err)
    else
      return disconnect()
    end
  end
  conn = remote.connect({host = host, port = port, lang = lang, ["on-message"] = handler["handle-message"], ["on-failure"] = _20_, ["on-success"] = _24_, ["on-error"] = _30_})
  return nil
end
local function eval_str(opts)
  local function _32_(conn)
    return request["env-eval"](conn, opts)
  end
  return with_conn_or_warn(_32_, opts)
end
local function eval_file(opts)
  local function _33_(conn)
    return request["env-load"](conn, opts)
  end
  return with_conn_or_warn(_33_, opts)
end
local function doc_str(opts)
  local function _34_(conn)
    return request["env-doc"](conn, opts)
  end
  return with_conn_or_warn(_34_, opts)
end
local function def_str(opts)
  local function _35_(conn)
    return request["env-doc"](conn, opts)
  end
  return with_conn_or_warn(_35_, opts)
end
local function add_breakpoint()
  local function _36_(conn)
    local bufnr = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]
    local cursor_col = cursor[2]
    local root_form = extract.form({["root?"] = true})
    if root_form then
      local form_content = root_form.content
      local form_range = root_form.range
      local form_start_line = (form_range[1] + 1)
      local form_start_col = form_range[2]
      local rel_line = (cursor_line - form_start_line)
      local rel_col
      if (cursor_line == form_start_line) then
        rel_col = (cursor_col - form_start_col)
      else
        rel_col = cursor_col
      end
      return request["dbg-brk-add"](conn, {["file-path"] = file_path, line = rel_line, col = rel_col, bufnr = bufnr, form = form_content})
    else
      return log.append("error", {"Cursor not in a root form"})
    end
  end
  return with_conn_or_warn(_36_, {})
end
local function continue_execution()
  local function _39_(conn)
    return request["dbg-step-cont"](conn, {})
  end
  return with_conn_or_warn(_39_, {})
end
local function inspect_stack()
  local function _40_(conn)
    return request["dbg-insp-stk"](conn, {})
  end
  return with_conn_or_warn(_40_, {})
end
local function remove_breakpoint()
  local function _41_(conn)
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local bp_data = ui["get-breakpoint-at-line"](bufnr, line)
    if bp_data then
      local signs = vim.fn.sign_getplaced(bufnr, {lnum = line, group = "grapple_breakpoints"})
      local buf_signs = signs[1]
      local sign_list = buf_signs.signs
      local sign = sign_list[1]
      local sign_id = sign.id
      return request["dbg-brk-rem"](conn, {["bp-id"] = bp_data["bp-id"], ["sign-id"] = sign_id})
    else
      return log.append("error", {"No breakpoint at current line"})
    end
  end
  return with_conn_or_warn(_41_, {})
end
local function clear_breakpoints()
  local function _43_(conn)
    return request["dbg-brk-clr"](conn, {})
  end
  return with_conn_or_warn(_43_, {})
end
local function on_filetype()
  ui["init-breakpoint-signs"]()
  ui["init-debug-sign"]()
  mapping.buf("JanetDisconnect", config["get-in"]({"client", "janet", "mrepl", "mapping", "disconnect"}), disconnect, {desc = "Disconnect from the REPL"})
  local function _44_()
    return connect()
  end
  mapping.buf("JanetConnect", config["get-in"]({"client", "janet", "mrepl", "mapping", "connect"}), _44_, {desc = "Connect to a REPL"})
  local function _45_()
    return start_server({})
  end
  mapping.buf("JanetStart", config["get-in"]({"client", "janet", "mrepl", "mapping", "start-server"}), _45_, {desc = "Start the Grapple server"})
  mapping.buf("JanetStop", config["get-in"]({"client", "janet", "mrepl", "mapping", "stop-server"}), stop_server, {desc = "Stop the Grapple server"})
  mapping.buf("JanetAddBreakpoint", config["get-in"]({"client", "janet", "mrepl", "mapping", "add-breakpoint"}), add_breakpoint, {desc = "Add a breakpoint at the cursor"})
  mapping.buf("JanetRemoveBreakpoint", config["get-in"]({"client", "janet", "mrepl", "mapping", "remove-breakpoint"}), remove_breakpoint, {desc = "Remove a breakpoint at the cursor"})
  mapping.buf("JanetClearBreakpoints", config["get-in"]({"client", "janet", "mrepl", "mapping", "clear-breakpoints"}), clear_breakpoints, {desc = "Clear all breakpoints"})
  mapping.buf("JanetContinue", config["get-in"]({"client", "janet", "mrepl", "mapping", "continue"}), continue_execution, {desc = "Continue execution from breakpoint"})
  return mapping.buf("JanetInspectStack", config["get-in"]({"client", "janet", "mrepl", "mapping", "inspect-stack"}), inspect_stack, {desc = "Inspect the current stack"})
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
    local function _47_(result)
      return on_result(("=> " .. result))
    end
    return n.assoc(opts, "on-result", _47_)
  else
    return opts
  end
end
return {["buf-suffix"] = buf_suffix, ["comment-node?"] = comment_node_3f, ["comment-prefix"] = comment_prefix, ["start-server"] = start_server, ["stop-server"] = stop_server, connect = connect, disconnect = disconnect, ["def-str"] = def_str, ["doc-str"] = doc_str, ["eval-file"] = eval_file, ["eval-str"] = eval_str, ["form-node?"] = form_node_3f, ["modify-client-exec-fn-opts"] = modify_client_exec_fn_opts, ["on-exit"] = on_exit, ["on-filetype"] = on_filetype, ["on-load"] = on_load, ["add-breakpoint"] = add_breakpoint, ["remove-breakpoint"] = remove_breakpoint, ["continue-execution"] = continue_execution, ["inspect-stack"] = inspect_stack, ["clear-breakpoints"] = clear_breakpoints}

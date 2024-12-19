-- [nfnl] Compiled from fnl/grapple/client/handler.fnl by https://github.com/Olical/nfnl, do not edit.
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local editor = autoload("conjure.editor")
local log = autoload("conjure.log")
local n = autoload("nfnl.core")
local state = autoload("grapple.client.state")
local str = autoload("nfnl.string")
local function upcase(s, n0)
  local start = string.sub(s, 1, n0)
  local rest = string.sub(s, (n0 + 1))
  return (string.upper(start) .. rest)
end
local function error_msg_3f(msg)
  return ("err" == msg.tag)
end
local function display_error(desc, msg)
  log.append({("# ! " .. desc)})
  if msg then
    return log.append({("# ! in " .. msg["janet/path"] .. " on line " .. msg["janet/line"] .. " at col " .. msg["janet/col"])})
  else
    return nil
  end
end
local function handle_sess_new(resp)
  n.assoc(state.get("conn"), "session", resp.sess)
  local impl_name = resp["janet/impl"][1]
  local impl_ver = resp["janet/impl"][2]
  local serv_name = resp["janet/serv"][1]
  local serv_ver = resp["janet/serv"][2]
  return log.append({("# Connected to " .. upcase(serv_name, 1) .. " v" .. serv_ver .. " running " .. upcase(impl_name, 1) .. " v" .. impl_ver .. " as session " .. resp.sess)})
end
local function handle_env_eval(resp)
  if (("out" == resp.tag) and ("out" == resp.ch)) then
    return log.append({("# (out) " .. resp.val)})
  elseif (("out" == resp.tag) and ("err" == resp.ch)) then
    return log.append({("# (err) " .. resp.val)})
  else
    return log.append({resp.val})
  end
end
local function handle_env_doc(resp, action)
  if ("doc" == action) then
    local buf = vim.api.nvim_create_buf(false, true)
    local sm_info
    local _4_
    if not resp["janet/sm"] then
      _4_ = "\n"
    else
      local path = resp["janet/sm"][1]
      local line = resp["janet/sm"][2]
      local col = resp["janet/sm"][3]
      _4_ = (path .. " on line " .. line .. ", column " .. col .. "\n\n")
    end
    sm_info = (resp["janet/type"] .. "\n" .. _4_)
    local lines = str.split((sm_info .. resp.val), "\n")
    local _ = vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local width = 50
    local height = 10
    local win_opts = {relative = "cursor", width = width, height = height, col = 0, row = 1, anchor = "NW", style = "minimal", border = "rounded"}
    local win = vim.api.nvim_open_win(buf, false, win_opts)
    vim.api.nvim_buf_set_option(buf, "wrap", true)
    vim.api.nvim_buf_set_option(buf, "linebreak", true)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    local function _7_()
      vim.api.nvim_win_close(win, true)
      vim.api.nvim_buf_delete(buf, {force = true})
      return nil
    end
    return vim.api.nvim_create_autocmd("CursorMoved", {once = true, callback = _7_})
  elseif ("def" == action) then
    local path = resp["janet/sm"][1]
    local line = resp["janet/sm"][2]
    local col = resp["janet/sm"][3]
    local stat = vim.loop.fs_stat(path)
    if (stat and ("file" == stat.type)) then
      return editor["go-to"](path, line, col)
    else
      return display_error("Oh no")
    end
  else
    return nil
  end
end
local function handle_message(msg, action)
  if msg then
    if error_msg_3f(msg) then
      return display_error(msg.val, msg)
    elseif ("sess.new" == msg.op) then
      return handle_sess_new(msg)
    elseif ("sess.end" == msg.op) then
      return __fnl_global__handle_2dsess_2dend(msg)
    elseif ("sess.list" == msg.op) then
      return __fnl_global__handle_2dsess_2dlist(msg)
    elseif ("serv.info" == msg.op) then
      return __fnl_global__handle_2dsess_2dinfo(msg)
    elseif ("serv.stop" == msg.op) then
      return __fnl_global__handle_2dserv_2dstop(msg)
    elseif ("serv.rest" == msg.op) then
      return __fnl_global__handle_2dserv_2drest(msg)
    elseif ("env.eval" == msg.op) then
      return handle_env_eval(msg)
    elseif ("env.load" == msg.op) then
      return handle_env_eval(msg)
    elseif ("env.stop" == msg.op) then
      return __fnl_global__handle_2denv_2dstop(msg)
    elseif ("env.doc" == msg.op) then
      return handle_env_doc(msg, action)
    elseif ("env.cmpl" == msg.op) then
      return __fnl_global__handle_2denv_2dcmpl(msg)
    else
      return log.append({"# Unrecognised message"})
    end
  else
    return nil
  end
end
return {["handle-message"] = handle_message}

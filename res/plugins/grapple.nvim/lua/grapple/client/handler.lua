-- [nfnl] fnl/grapple/client/handler.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local editor = autoload("conjure.editor")
local log = autoload("grapple.client.log")
local n = autoload("conjure.nfnl.core")
local state = autoload("grapple.client.state")
local str = autoload("conjure.nfnl.string")
local function upcase(s, n0)
  local start = string.sub(s, 1, n0)
  local rest = string.sub(s, (n0 + 1))
  return (string.upper(start) .. rest)
end
local function error_msg_3f(msg)
  return ("err" == msg.tag)
end
local function display_error(desc, msg)
  log.append("error", {desc})
  if (msg and msg["janet/path"] and msg["janet/line"] and msg["janet/col"]) then
    return log.append("error", {(" in " .. msg["janet/path"] .. " on line " .. msg["janet/line"] .. " at col " .. msg["janet/col"])})
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
  return log.append("info", {("Connected to " .. upcase(serv_name, 1) .. " v" .. serv_ver .. " running " .. upcase(impl_name, 1) .. " v" .. impl_ver .. " as session " .. resp.sess)})
end
local function handle_env_eval(resp, opts)
  if (nil == resp.val) then
    return nil
  elseif (("out" == resp.tag) and ("out" == resp.ch)) then
    return log.append("stdout", {resp.val})
  elseif (("out" == resp.tag) and ("err" == resp.ch)) then
    return log.append("stderr", {resp.val})
  elseif (("ret" == resp.tag) and (nil ~= resp.val)) then
    if opts["on-result"] then
      opts["on-result"](resp.val)
    else
    end
    return log.append("result", {resp.val})
  else
    return nil
  end
end
local function handle_env_doc(resp, action)
  if ("doc" == action) then
    local src_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    local sm_info
    local _5_
    if not resp["janet/sm"] then
      _5_ = "\n"
    else
      local path = resp["janet/sm"][1]
      local line = resp["janet/sm"][2]
      local col = resp["janet/sm"][3]
      _5_ = (path .. " on line " .. line .. ", column " .. col .. "\n\n")
    end
    sm_info = (resp["janet/type"] .. "\n" .. _5_)
    local lines = str.split((sm_info .. resp.val), "\n")
    local _ = vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local width = 50
    local height = 10
    local win_opts = {relative = "cursor", width = width, height = height, col = 0, row = 1, anchor = "NW", style = "minimal", border = "rounded"}
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    vim.keymap.set("n", "j", "gj", {buffer = buf, noremap = true, silent = true})
    vim.keymap.set("n", "k", "gk", {buffer = buf, noremap = true, silent = true})
    vim.keymap.set("n", "<Down>", "gj", {buffer = buf, noremap = true, silent = true})
    vim.keymap.set("n", "<Up>", "gk", {buffer = buf, noremap = true, silent = true})
    vim.keymap.set("n", "q", ":q<CR>", {buffer = buf, noremap = true, silent = true})
    vim.keymap.set("n", "<Esc>", ":q<CR>", {buffer = buf, noremap = true, silent = true})
    vim.api.nvim_buf_set_option(buf, "wrap", true)
    vim.api.nvim_buf_set_option(buf, "linebreak", true)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_win_set_option(win, "scrolloff", 0)
    vim.api.nvim_win_set_option(win, "sidescrolloff", 0)
    vim.api.nvim_win_set_option(win, "breakindent", true)
    local function _8_()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      else
      end
      vim.api.nvim_buf_delete(buf, {force = true})
      return nil
    end
    return vim.api.nvim_create_autocmd("CursorMoved", {buffer = src_buf, once = true, callback = _8_})
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
local function handle_message(msg, opts)
  if msg then
    local action = ((opts and opts.action) or nil)
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
      return handle_env_eval(msg, opts)
    elseif ("env.load" == msg.op) then
      return handle_env_eval(msg, opts)
    elseif ("env.stop" == msg.op) then
      return __fnl_global__handle_2denv_2dstop(msg)
    elseif ("env.doc" == msg.op) then
      return handle_env_doc(msg, action)
    elseif ("env.cmpl" == msg.op) then
      return __fnl_global__handle_2denv_2dcmpl(msg)
    else
      return log.append("error", {"Unrecognised message"})
    end
  else
    return nil
  end
end
return {["handle-message"] = handle_message}

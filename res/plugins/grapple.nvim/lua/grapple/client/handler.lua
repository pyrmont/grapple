-- [nfnl] fnl/grapple/client/handler.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local editor = autoload("conjure.editor")
local log = autoload("grapple.client.log")
local n = autoload("conjure.nfnl.core")
local state = autoload("grapple.client.state")
local str = autoload("conjure.nfnl.string")
local ui = autoload("grapple.client.ui")
local debugger = autoload("grapple.client.debugger")
local function show_nls(s)
  local with_arrows = string.gsub(s, "\r?\n", "\226\134\181\n")
  local lines = str.split(with_arrows, "\n")
  if ((#lines > 1) and ("" == n.last(lines))) then
    table.remove(lines)
  else
  end
  return lines
end
local function upcase(s, n0)
  local start = string.sub(s, 1, n0)
  local rest = string.sub(s, (n0 + 1))
  return (string.upper(start) .. rest)
end
local function render_janet_value(janet_result, st)
  if (type(janet_result) == "string") then
    return janet_result
  elseif ((type(janet_result) == "table") and janet_result.type) then
    local result_type = janet_result.type
    local result_count = (janet_result.count or 0)
    local result_length = (janet_result.length or 0)
    if ((result_length > 50) and (result_count > 20)) then
      local counter = (st["result-counter"] + 1)
      local id_str = string.format("%04x", counter)
      n.assoc(st, "result-counter", counter)
      n.assoc(st["id-to-val"], id_str, janet_result)
      return ("<" .. result_type .. "-" .. id_str .. " count:" .. result_count .. ">")
    else
      if (result_type == "array") then
        local function _3_(_241)
          return render_janet_value(_241, st)
        end
        return ("@[" .. str.join(" ", n.map(_3_, (janet_result.els or {}))) .. "]")
      elseif (result_type == "tuple") then
        local function _4_(_241)
          return render_janet_value(_241, st)
        end
        return ("[" .. str.join(" ", n.map(_4_, (janet_result.els or {}))) .. "]")
      elseif (result_type == "struct") then
        local kvs = (janet_result.kvs or {})
        local pairs = {}
        for i = 1, #kvs, 2 do
          local k = kvs[i]
          local v = kvs[(i + 1)]
          table.insert(pairs, (render_janet_value(k, st) .. " " .. render_janet_value(v, st)))
        end
        return ("{" .. str.join(" ", pairs) .. "}")
      elseif (result_type == "table") then
        local kvs = (janet_result.kvs or {})
        local pairs = {}
        for i = 1, #kvs, 2 do
          local k = kvs[i]
          local v = kvs[(i + 1)]
          table.insert(pairs, (render_janet_value(k, st) .. " " .. render_janet_value(v, st)))
        end
        return ("@{" .. str.join(" ", pairs) .. "}")
      else
        local _ = result_type
        return janet_result.value
      end
    end
  else
    return nil
  end
end
local function render_result(resp)
  local val = (resp.val or "")
  local janet_result = resp["janet/result"]
  if (#val < 50) then
    return val
  elseif janet_result then
    return render_janet_value(janet_result, state.get())
  else
    return val
  end
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
local function handle_cmd(resp)
  if ("clear-breakpoints" == resp.val) then
    local bp_ids = resp["janet/breakpoints"]
    local breakpoints = state.get("breakpoints")
    local removed_locations = {}
    for _, bp_id in ipairs(bp_ids) do
      for sign_id, bp_data in pairs(breakpoints) do
        if (bp_data["bp-id"] == bp_id) then
          local current_line = ui["get-sign-current-line"](sign_id)
          if current_line then
            table.insert(removed_locations, (bp_data["file-path"] .. ":" .. current_line))
          else
          end
          ui["remove-breakpoint-sign"](sign_id)
          break
        else
        end
      end
    end
    for _, location in ipairs(removed_locations) do
      log.append("info", {("Removed stale breakpoint at " .. location)})
    end
    return nil
  else
    return nil
  end
end
local function handle_env_eval(resp, opts)
  if (nil == resp.val) then
    return nil
  elseif (("out" == resp.tag) and ("out" == resp.ch)) then
    return log.append("stdout", show_nls(resp.val))
  elseif (("out" == resp.tag) and ("err" == resp.ch)) then
    return log.append("stderr", {resp.val})
  elseif ("cmd" == resp.tag) then
    return handle_cmd(resp)
  elseif ("note" == resp.tag) then
    return log.append("note", {resp.val})
  elseif (("sig" == resp.tag) and ("debug" == resp.val)) then
    return debugger["handle-signal"](resp)
  elseif (("ret" == resp.tag) and (nil ~= resp.val)) then
    local rendered = render_result(resp)
    if rendered then
      if (opts["on-result"] and not resp["janet/reeval?"]) then
        opts["on-result"](rendered)
      else
      end
      return log.append("result", {rendered})
    else
      return log.append("error", {"Failed to render result: unexpected janet/result structure"})
    end
  else
    return nil
  end
end
local function handle_env_dbg(resp, opts)
  if (("ret" == resp.tag) and (nil ~= resp.val)) then
    local rendered = render_result(resp)
    if rendered then
      return log.append("result", {rendered})
    else
      return log.append("error", {"Failed to render result: unexpected janet/result structure"})
    end
  else
    return handle_env_eval(resp, opts)
  end
end
local function handle_env_doc(resp, action)
  if ("doc" == action) then
    local src_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    local sm_info
    local _18_
    if not resp["janet/sm"] then
      _18_ = "\n"
    else
      local path = resp["janet/sm"][1]
      local line = resp["janet/sm"][2]
      local col = resp["janet/sm"][3]
      _18_ = (path .. " on line " .. line .. ", column " .. col .. "\n\n")
    end
    sm_info = (resp["janet/type"] .. "\n" .. _18_)
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
    local function _21_()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      else
      end
      vim.api.nvim_buf_delete(buf, {force = true})
      return nil
    end
    return vim.api.nvim_create_autocmd("CursorMoved", {buffer = src_buf, once = true, callback = _21_})
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
local function handle_brk_add(resp, opts)
  if ("ret" == resp.tag) then
    local bp_id = resp["janet/bp-id"]
    log.append("info", {("Added breakpoint at " .. opts["file-path"] .. ":" .. opts.line)})
    return ui["add-breakpoint-sign"](opts.bufnr, opts["file-path"], opts.line, bp_id)
  elseif ("err" == resp.tag) then
    return display_error(("Failed to add breakpoint: " .. resp.val), resp)
  else
    return nil
  end
end
local function handle_brk_rem(resp, opts)
  if ("ret" == resp.tag) then
    local breakpoints = state.get("breakpoints")
    local bp_data = breakpoints[opts["sign-id"]]
    local current_line = ui["get-sign-current-line"](opts["sign-id"])
    if (bp_data and current_line) then
      log.append("info", {("Removed breakpoint at " .. bp_data["file-path"] .. ":" .. current_line)})
    else
    end
    return ui["remove-breakpoint-sign"](opts["sign-id"])
  elseif ("err" == resp.tag) then
    return display_error(("Failed to remove breakpoint: " .. resp.val), resp)
  else
    return nil
  end
end
local function handle_brk_clr(resp)
  if ("ret" == resp.tag) then
    log.append("info", {"Cleared all breakpoints"})
    return ui["clear-breakpoint-signs"]()
  elseif ("err" == resp.tag) then
    return display_error(("Failed to clear breakpoints: " .. resp.val), resp)
  else
    return nil
  end
end
local function handle_brk_list(resp, opts)
  if ("ret" == resp.tag) then
    local rendered = render_result(resp)
    if rendered then
      return log.append("result", {rendered})
    else
      return log.append("error", {"Failed to render result: unexpected janet/result structure"})
    end
  elseif ("err" == resp.tag) then
    return display_error(("Failed to list breakpoints: " .. resp.val), resp)
  else
    return nil
  end
end
local function handle_message(msg, opts)
  if msg then
    local action = ((opts and opts.action) or nil)
    if (error_msg_3f(msg) and ("sess.new" == msg.op) and string.find((msg.val or ""), "authentication failed") and opts["on-auth-error"]) then
      return opts["on-auth-error"]()
    elseif error_msg_3f(msg) then
      return display_error(msg.val, msg)
    elseif ("sess.new" == msg.op) then
      return handle_sess_new(msg)
    elseif ("sess.end" == msg.op) then
      return __fnl_global__handle_2dsess_2dend(msg)
    elseif ("sess.list" == msg.op) then
      return __fnl_global__handle_2dsess_2dlist(msg)
    elseif ("mgmt.info" == msg.op) then
      return __fnl_global__handle_2dmgmt_2dinfo(msg)
    elseif ("mgmt.stop" == msg.op) then
      return __fnl_global__handle_2dmgmt_2dstop(msg)
    elseif ("mgmt.rest" == msg.op) then
      return __fnl_global__handle_2dmgmt_2drest(msg)
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
    elseif ("env.dbg" == msg.op) then
      return handle_env_dbg(msg, opts)
    elseif ("brk.add" == msg.op) then
      return handle_brk_add(msg, opts)
    elseif ("brk.rem" == msg.op) then
      return handle_brk_rem(msg, opts)
    elseif ("brk.clr" == msg.op) then
      return handle_brk_clr(msg)
    elseif ("brk.list" == msg.op) then
      return handle_brk_list(msg, opts)
    else
      return log.append("error", {"Unrecognised message"})
    end
  else
    return nil
  end
end
return {["handle-message"] = handle_message}

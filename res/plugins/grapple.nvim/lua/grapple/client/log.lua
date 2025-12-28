-- [nfnl] fnl/grapple/client/log.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local client = autoload("conjure.client")
local log = autoload("conjure.log")
local n = autoload("conjure.nfnl.core")
local state = autoload("grapple.client.state")
local str = autoload("conjure.nfnl.string")
local info_header = "======= info ======="
local error_header = "====== error ======="
local input_header = "====== input ======="
local note_header = "======= note ======="
local result_header = "====== result ======"
local stdout_header = "====== stdout ======"
local stderr_header = "====== stderr ======"
local ns = vim.api.nvim_create_namespace("grapple-log")
local function highlight_lines(buf, start, _end, hl_group)
  return vim.api.nvim_buf_set_extmark(buf, ns, start, 0, {end_row = _end, hl_group = hl_group, priority = 200})
end
local function log_buf_name()
  return str.join({"conjure-log-", vim.fn.getpid(), client.get("buf-suffix")})
end
local function append(sec, lines, opts)
  if not n["empty?"](lines) then
    local buf = vim.fn.bufnr(log_buf_name())
    local curr_sec = state.get("log-sec")
    local add_heading_3f = (curr_sec ~= sec)
    local start_line = vim.api.nvim_buf_line_count(buf)
    local function _2_()
      if (sec == "info") then
        return {info_header, "Title"}
      elseif (sec == "error") then
        return {error_header, "ErrorMsg"}
      elseif (sec == "input") then
        return {input_header, nil}
      elseif (sec == "note") then
        return {note_header, "Special"}
      elseif (sec == "stdout") then
        return {stdout_header, "String"}
      elseif (sec == "stderr") then
        return {stderr_header, "WarningMsg"}
      else
        local _ = sec
        return {result_header, nil}
      end
    end
    local _let_3_ = _2_()
    local header = _let_3_[1]
    local hl_group = _let_3_[2]
    if add_heading_3f then
      n.assoc(state.get(), "log-sec", sec)
      log["immediate-append"]({header})
      highlight_lines(buf, start_line, (start_line + 1), "Comment")
    else
    end
    log["immediate-append"](lines, opts)
    if hl_group then
      local _5_
      if add_heading_3f then
        _5_ = 1
      else
        _5_ = 0
      end
      return highlight_lines(buf, (start_line + _5_), vim.api.nvim_buf_line_count(buf), hl_group)
    else
      return nil
    end
  else
    return nil
  end
end
local function buf()
  log["last-line"]()
  return vim.fn.bufnr(log_buf_name())
end
return {append = append, buf = buf}

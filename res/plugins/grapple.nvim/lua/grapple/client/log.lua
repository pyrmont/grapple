-- [nfnl] fnl/grapple/client/log.fnl
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local client = autoload("conjure.client")
local log = autoload("conjure.log")
local n = autoload("nfnl.core")
local state = autoload("grapple.client.state")
local str = autoload("conjure.nfnl.string")
local info_header = "======= info ======="
local error_header = "====== error ======="
local input_header = "====== input ======="
local result_header = "====== result ======"
local stdout_header = "====== stdout ======"
local stderr_header = "====== stderr ======"
local ns = vim.api.nvim_create_namespace("grapple-log")
local function highlight_lines(buf, start_line, end_line, hl_group)
  for line = start_line, (end_line - 1) do
    vim.api.nvim_buf_add_highlight(buf, ns, hl_group, line, 0, -1)
  end
  return nil
end
local function log_buf_name()
  return str.join({"conjure-log-", vim.fn.getpid(), client.get("buf-suffix")})
end
local function append(sec, lines, opts)
  if not n["empty?"](lines) then
    local buf = vim.fn.bufnr(log_buf_name())
    local curr_sec = state.get("log-sec")
    if (curr_sec ~= sec) then
      n.assoc(state.get(), "log-sec", sec)
      local header
      if (sec == "info") then
        header = info_header
      elseif (sec == "error") then
        header = error_header
      elseif (sec == "input") then
        header = input_header
      elseif (sec == "result") then
        header = result_header
      elseif (sec == "stdout") then
        header = stdout_header
      elseif (sec == "stderr") then
        header = stderr_header
      else
        header = nil
      end
      log.append({header})
      local line_count = vim.api.nvim_buf_line_count(buf)
      highlight_lines(buf, (line_count - 1), line_count, "Comment")
    else
    end
    local start_line = vim.api.nvim_buf_line_count(buf)
    log.append(lines, opts)
    if start_line then
      local end_line = vim.api.nvim_buf_line_count(buf)
      if (sec == "info") then
        return highlight_lines(buf, start_line, end_line, "Title")
      elseif (sec == "error") then
        return highlight_lines(buf, start_line, end_line, "ErrorMsg")
      elseif (sec == "stdout") then
        return highlight_lines(buf, start_line, end_line, "String")
      elseif (sec == "stderr") then
        return highlight_lines(buf, start_line, end_line, "WarningMsg")
      else
        local _ = sec
        return nil
      end
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

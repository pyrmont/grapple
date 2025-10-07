-- [nfnl] fnl/grapple/client/log.fnl
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local client = autoload("conjure.client")
local log = autoload("conjure.log")
local function log_buf_name()
  return ("conjure-log-" .. vim.fn.getpid() .. (client.get("buf-suffix") or ""))
end
local function append(lines, opts)
  return log.append(lines, opts)
end
local function setup_syntax(buf)
  local function _2_()
    vim.cmd("runtime! syntax/janet.vim")
    vim.cmd("syntax region GrappleResult start=/^[^#]/ end=/$/ contains=@JanetTop")
    vim.cmd("syntax match GrappleComment \"^# .*\"")
    vim.cmd("syntax match GrappleError \"^# ! .*\"")
    vim.cmd("highlight link GrappleComment Comment")
    return vim.cmd("highlight link GrappleError Error")
  end
  return vim.api.nvim_buf_call(buf, _2_)
end
local function bufnr()
  local ok_3f, buf = pcall(vim.api.nvim_buf_call, log_buf_name())
  if ok_3f then
    setup_syntax(buf)
  else
  end
  if ok_3f then
    return buf
  else
    return error("Conjure could not get buffer number for log")
  end
end
return {append = append, bufnr = bufnr}

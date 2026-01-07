-- [nfnl] fnl/grapple/client/ui.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local n = autoload("conjure.nfnl.core")
local state = autoload("grapple.client.state")
local function init_breakpoint_signs()
  return vim.fn.sign_define("GrappleBreakpoint", {text = "\226\151\143", texthl = "DiagnosticInfo", linehl = "", numhl = ""})
end
local function add_breakpoint_sign(bufnr, file_path, line)
  local sign_id = vim.fn.sign_place(0, "grapple_breakpoints", "GrappleBreakpoint", bufnr, {lnum = line})
  local bp_key = (file_path .. ":" .. line)
  local breakpoints = state.get("breakpoints")
  n.assoc(breakpoints, bp_key, {bufnr = bufnr, line = line, ["sign-id"] = sign_id})
  return sign_id
end
local function remove_breakpoint_sign(file_path, line)
  local bp_key = (file_path .. ":" .. line)
  local breakpoints = state.get("breakpoints")
  local bp_data = breakpoints[bp_key]
  if bp_data then
    vim.fn.sign_unplace("grapple_breakpoints", {id = bp_data["sign-id"], buffer = bp_data.bufnr})
    return n.assoc(breakpoints, bp_key, nil)
  else
    return nil
  end
end
local function clear_breakpoint_signs()
  local breakpoints = state.get("breakpoints")
  for bp_key, bp_data in pairs(breakpoints) do
    vim.fn.sign_unplace("grapple_breakpoints", {id = bp_data["sign-id"], buffer = bp_data.bufnr})
  end
  return n.assoc(state.get(), "breakpoints", {})
end
local function init_debug_sign()
  return vim.fn.sign_define("GrappleDebugPosition", {text = "\226\134\146", texthl = "DiagnosticWarn", linehl = "", numhl = ""})
end
local function show_debug_indicators(bufnr, file_path, line)
  do
    local sign_id = vim.fn.sign_place(0, "grapple_debug", "GrappleDebugPosition", bufnr, {lnum = line})
    n.assoc(state.get(), "debug-position", {bufnr = bufnr, ["file-path"] = file_path, line = line, ["sign-id"] = sign_id})
  end
  local original_hl = vim.api.nvim_get_hl(0, {name = "SignColumn"})
  n.assoc(state.get(), "original-signcol-hl", original_hl)
  return vim.api.nvim_set_hl(0, "SignColumn", {bg = "#3e2723"})
end
local function hide_debug_indicators()
  do
    local debug_pos = state.get("debug-position")
    if debug_pos then
      vim.fn.sign_unplace("grapple_debug", {id = debug_pos["sign-id"], buffer = debug_pos.bufnr})
      n.assoc(state.get(), "debug-position", nil)
    else
    end
  end
  local original_hl = state.get("original-signcol-hl")
  if original_hl then
    vim.api.nvim_set_hl(0, "SignColumn", original_hl)
    return n.assoc(state.get(), "original-signcol-hl", nil)
  else
    return nil
  end
end
return {["init-breakpoint-signs"] = init_breakpoint_signs, ["add-breakpoint-sign"] = add_breakpoint_sign, ["remove-breakpoint-sign"] = remove_breakpoint_sign, ["clear-breakpoint-signs"] = clear_breakpoint_signs, ["init-debug-sign"] = init_debug_sign, ["show-debug-indicators"] = show_debug_indicators, ["hide-debug-indicators"] = hide_debug_indicators}

-- [nfnl] fnl/grapple/client/debugger.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local n = autoload("conjure.nfnl.core")
local state = autoload("grapple.client.state")
local request = autoload("grapple.client.request")
local str = autoload("conjure.nfnl.string")
local log = autoload("grapple.client.log")
local ui = autoload("grapple.client.ui")
local debugger_state = nil
local function create_debugger_buffers()
  local fiber_state_buf = vim.api.nvim_create_buf(false, true)
  local bytecode_buf = vim.api.nvim_create_buf(false, true)
  local source_buf = vim.api.nvim_create_buf(false, true)
  local input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(fiber_state_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(fiber_state_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(fiber_state_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(fiber_state_buf, "filetype", "grapple-fiber-state")
  vim.api.nvim_buf_set_option(bytecode_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bytecode_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bytecode_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(bytecode_buf, "filetype", "grapple-bytecode")
  vim.api.nvim_buf_set_option(source_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(source_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(source_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(source_buf, "filetype", "janet")
  vim.api.nvim_buf_set_option(input_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(input_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(input_buf, "modifiable", true)
  vim.api.nvim_buf_set_option(input_buf, "filetype", "janet")
  vim.api.nvim_buf_set_var(input_buf, "grapple_debug_input", true)
  return {["fiber-state-buf"] = fiber_state_buf, ["bytecode-buf"] = bytecode_buf, ["source-buf"] = source_buf, ["input-buf"] = input_buf}
end
local function create_tab_layout(bufs)
  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()
  local log_buf = log.buf()
  local initial_win = vim.api.nvim_get_current_win()
  local fiber_state_win = initial_win
  vim.api.nvim_win_set_buf(fiber_state_win, bufs["fiber-state-buf"])
  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  local source_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(source_win, bufs["source-buf"])
  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  local log_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(log_win, log_buf)
  vim.api.nvim_set_current_win(fiber_state_win)
  vim.cmd("split")
  vim.cmd("wincmd j")
  local bytecode_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(bytecode_win, bufs["bytecode-buf"])
  vim.api.nvim_set_current_win(source_win)
  vim.cmd("split")
  vim.cmd("wincmd j")
  local input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_win, bufs["input-buf"])
  return {tab = tab, ["fiber-state-win"] = fiber_state_win, ["bytecode-win"] = bytecode_win, ["source-win"] = source_win, ["input-win"] = input_win, ["log-win"] = log_win}
end
local function close_debugger_ui()
  if debugger_state then
    if (debugger_state.tab and vim.api.nvim_tabpage_is_valid(debugger_state.tab)) then
      local current_tab = vim.api.nvim_get_current_tabpage()
      if (current_tab ~= debugger_state.tab) then
        vim.cmd(("tabn " .. vim.api.nvim_tabpage_get_number(debugger_state.tab)))
      else
      end
      vim.cmd("tabclose")
    else
    end
    for _, buf_key in ipairs({"fiber-state-buf", "bytecode-buf", "source-buf", "input-buf"}) do
      local buf = debugger_state[buf_key]
      if (buf and vim.api.nvim_buf_is_valid(buf)) then
        pcall(vim.api.nvim_buf_delete, buf, {force = true})
      else
      end
    end
    debugger_state = nil
    return nil
  else
    return nil
  end
end
local function set_buffer_content(buf, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return vim.api.nvim_buf_set_option(buf, "modifiable", false)
end
local function format_fiber_state(fiber_state, stack)
  local lines = {}
  if fiber_state then
    table.insert(lines, "Fiber State")
    table.insert(lines, "-----------")
    for _, line in ipairs(vim.split(fiber_state, "\n", {plain = true})) do
      table.insert(lines, line)
    end
    table.insert(lines, "")
  else
  end
  if (stack and (#stack > 0)) then
    table.insert(lines, "Stack Frames")
    table.insert(lines, "------------")
    for i, frame in ipairs(stack) do
      local name = (frame.name or "<anonymous>")
      local path = (frame.path or "?")
      local line = (frame.line or "?")
      local pc = (frame.pc or "?")
      local tail
      if frame.tail then
        tail = " [tail]"
      else
        tail = ""
      end
      table.insert(lines, ("Frame " .. (i - 1) .. ": " .. name))
      table.insert(lines, ("  " .. "path: " .. path))
      table.insert(lines, ("  " .. "line: " .. line))
      table.insert(lines, ("  " .. "pc: " .. pc))
      if not ("" == tail) then
        table.insert(lines, ("  " .. "tail?: " .. "true"))
      else
      end
    end
  else
    table.insert(lines, "No stack frames available")
  end
  return lines
end
local function format_source(stack)
  if (stack and (#stack > 0)) then
    local frame = stack[1]
    local path = (frame.path or nil)
    if path then
      local ok_3f, lines = pcall(vim.fn.readfile, path)
      if ok_3f then
        return lines
      else
        return {("Could not read file: " .. path)}
      end
    else
      return {"No source file available"}
    end
  else
    return {"No stack frames available"}
  end
end
local function format_bytecode(asm)
  if asm then
    local lines = {}
    table.insert(lines, "Instructions")
    table.insert(lines, "------------")
    for _, line in ipairs(vim.split(asm, "\n", {plain = true})) do
      table.insert(lines, line)
    end
    return lines
  else
    return {"No bytecode available"}
  end
end
local function update_fiber_state_window(fiber_state, stack)
  if debugger_state then
    local lines = format_fiber_state(fiber_state, stack)
    return set_buffer_content(debugger_state["fiber-state-buf"], lines)
  else
    return nil
  end
end
local function update_source_window(stack)
  if debugger_state then
    if (stack and (#stack > 0)) then
      local frame = stack[1]
      local path = frame.path
      local line = frame.line
      if path then
        do
          local bufnr = vim.fn.bufnr(path)
          if (bufnr == -1) then
            local new_buf = vim.fn.bufadd(path)
            vim.fn.bufload(new_buf)
            vim.api.nvim_win_set_buf(debugger_state["source-win"], new_buf)
          else
            vim.api.nvim_win_set_buf(debugger_state["source-win"], bufnr)
          end
        end
        if (line and (line > 0)) then
          if (debugger_state["source-win"] and vim.api.nvim_win_is_valid(debugger_state["source-win"])) then
            return pcall(vim.api.nvim_win_set_cursor, debugger_state["source-win"], {line, 0})
          else
            return nil
          end
        else
          return nil
        end
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function update_bytecode_window(asm)
  if debugger_state then
    local lines = format_bytecode(asm)
    return set_buffer_content(debugger_state["bytecode-buf"], lines)
  else
    return nil
  end
end
local function send_debug_command(code)
  if debugger_state then
    local conn = state.get("conn")
    local req = debugger_state.req
    if not conn then
      return log.append("error", {"Not connected to server"})
    else
      if not req then
        return log.append("error", {"No active debug session"})
      else
        return request["env-dbg"](conn, {code = code, req = req})
      end
    end
  else
    return nil
  end
end
local function continue_execution()
  send_debug_command("(.continue)")
  return ui["hide-debug-indicators"]()
end
local function step_execution()
  send_debug_command("(.step)")
  return ui["hide-debug-indicators"]()
end
local function setup_buffer_keymaps(bufs)
  local function set_on_all(key, callback)
    for _, buf in pairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) then
        local opts = {buffer = buf, noremap = true, silent = true}
        vim.keymap.set("n", key, callback, opts)
      else
      end
    end
    return nil
  end
  set_on_all("<localleader>dc", continue_execution)
  return set_on_all("<localleader>ds", step_execution)
end
local function open_debugger_ui(stack, fiber_state, bytecode, req)
  local saved_input_content
  if (debugger_state and debugger_state["input-buf"] and vim.api.nvim_buf_is_valid(debugger_state["input-buf"])) then
    saved_input_content = vim.api.nvim_buf_get_lines(debugger_state["input-buf"], 0, -1, false)
  else
    saved_input_content = nil
  end
  local saved_cursor
  if (debugger_state and debugger_state["input-win"] and vim.api.nvim_win_is_valid(debugger_state["input-win"]) and (vim.api.nvim_get_current_win() == debugger_state["input-win"])) then
    saved_cursor = vim.api.nvim_win_get_cursor(debugger_state["input-win"])
  else
    saved_cursor = nil
  end
  close_debugger_ui()
  local bufs = create_debugger_buffers()
  local layout = create_tab_layout(bufs)
  debugger_state = {tab = layout.tab, ["fiber-state-buf"] = bufs["fiber-state-buf"], ["bytecode-buf"] = bufs["bytecode-buf"], ["source-buf"] = bufs["source-buf"], ["input-buf"] = bufs["input-buf"], ["fiber-state-win"] = layout["fiber-state-win"], ["bytecode-win"] = layout["bytecode-win"], ["source-win"] = layout["source-win"], ["input-win"] = layout["input-win"], ["log-win"] = layout["log-win"], req = req, stack = stack, ["fiber-state"] = fiber_state, bytecode = bytecode}
  vim.api.nvim_win_set_option(layout["fiber-state-win"], "wrap", false)
  vim.api.nvim_win_set_option(layout["fiber-state-win"], "number", false)
  vim.api.nvim_win_set_option(layout["fiber-state-win"], "relativenumber", false)
  vim.api.nvim_win_set_option(layout["fiber-state-win"], "signcolumn", "no")
  vim.api.nvim_win_set_option(layout["bytecode-win"], "wrap", false)
  vim.api.nvim_win_set_option(layout["bytecode-win"], "number", false)
  vim.api.nvim_win_set_option(layout["bytecode-win"], "relativenumber", false)
  vim.api.nvim_win_set_option(layout["bytecode-win"], "signcolumn", "no")
  vim.api.nvim_win_set_option(layout["source-win"], "wrap", false)
  vim.api.nvim_win_set_option(layout["input-win"], "wrap", false)
  update_fiber_state_window(fiber_state, stack)
  update_source_window(stack)
  update_bytecode_window(bytecode)
  if saved_input_content then
    vim.api.nvim_buf_set_lines(bufs["input-buf"], 0, -1, false, saved_input_content)
  else
    vim.api.nvim_buf_set_lines(bufs["input-buf"], 0, -1, false, {"# Debugger Input", "# --------------", "# Expressions evaluated by Conjure in this buffer are evaluated", "# in the debugging environment.", "#", "# Debug commands:", "#   (.continue)   - Continue execution", "#   (.ppasm)      - Pretty print disassembly", "#   (.step)       - Step to next instruction", "#", "# Keybindings:", "#   <localleader>dc - Continue", "#   <localleader>ds - Step", "", ""})
  end
  setup_buffer_keymaps(bufs)
  vim.api.nvim_set_current_win(layout["input-win"])
  if saved_cursor then
    vim.api.nvim_win_set_cursor(layout["input-win"], saved_cursor)
  else
    local line_count = vim.api.nvim_buf_line_count(bufs["input-buf"])
    vim.api.nvim_win_set_cursor(layout["input-win"], {line_count, 0})
  end
  return debugger_state
end
local function handle_signal(resp)
  local stack = resp["janet/stack"]
  local fiber_state = resp["janet/fiber-state"]
  local bytecode = resp["janet/bytecode"]
  local req = resp.req
  local file_path = resp["janet/path"]
  local line = resp["janet/line"]
  log.append("info", {"Paused evaluation"})
  ui["hide-debug-indicators"]()
  if (file_path and line) then
    local bufnr = vim.fn.bufnr(file_path)
    if (bufnr ~= -1) then
      ui["show-debug-indicators"](bufnr, file_path, line)
    else
    end
  else
  end
  return open_debugger_ui(stack, fiber_state, bytecode, req)
end
local function is_input_buffer_3f(bufnr)
  return (debugger_state and (bufnr == debugger_state["input-buf"]))
end
local function get_debug_req()
  if debugger_state then
    return debugger_state.req
  else
    return nil
  end
end
return {["continue-execution"] = continue_execution, ["step-execution"] = step_execution, ["handle-signal"] = handle_signal, ["is-input-buffer?"] = is_input_buffer_3f, ["get-debug-req"] = get_debug_req}

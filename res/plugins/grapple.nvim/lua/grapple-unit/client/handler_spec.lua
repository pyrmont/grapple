-- [nfnl] fnl/grapple-unit/client/handler_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local assert = require("luassert.assert")
local log_calls = {}
local state_data = {conn = {}, breakpoints = {}}
local editor_calls = {}
local ui_calls = {}
local debugger_calls = {}
local mock_log
local function _2_(sec, lines)
  return table.insert(log_calls, {sec = sec, lines = lines})
end
local function _3_()
  return 999
end
mock_log = {append = _2_, buf = _3_}
local mock_state
local function _4_(key)
  if key then
    return state_data[key]
  else
    return state_data
  end
end
mock_state = {get = _4_}
local mock_editor
local function _6_(path, line, col)
  return table.insert(editor_calls, {path = path, line = line, col = col})
end
mock_editor = {["go-to"] = _6_}
local mock_str
local function _7_(text, sep)
  local result = {}
  for part in string.gmatch(text, ("[^" .. sep .. "]+")) do
    table.insert(result, part)
  end
  return result
end
mock_str = {split = _7_}
local mock_ui
local function _8_(bufnr, file_path, line, bp_id)
  return table.insert(ui_calls, {op = "add", bufnr = bufnr, ["file-path"] = file_path, line = line, ["bp-id"] = bp_id})
end
local function _9_(sign_id)
  if (sign_id == 123) then
    return 10
  else
    return nil
  end
end
local function _11_(sign_id)
  return table.insert(ui_calls, {op = "remove", ["sign-id"] = sign_id})
end
local function _12_()
  return table.insert(ui_calls, {op = "clear"})
end
local function _13_(bufnr, file_path, line)
  return table.insert(ui_calls, {op = "show-debug", bufnr = bufnr, ["file-path"] = file_path, line = line})
end
local function _14_()
  return table.insert(ui_calls, {op = "hide-debug"})
end
mock_ui = {["add-breakpoint-sign"] = _8_, ["get-sign-current-line"] = _9_, ["remove-breakpoint-sign"] = _11_, ["clear-breakpoint-signs"] = _12_, ["show-debug-indicators"] = _13_, ["hide-debug-indicators"] = _14_}
local mock_debugger
local function _15_(msg)
  return table.insert(debugger_calls, {msg = msg})
end
mock_debugger = {["handle-signal"] = _15_}
local n = require("nfnl.core")
package.loaded["grapple.client.log"] = mock_log
package.loaded["grapple.client.state"] = mock_state
package.loaded["grapple.client.ui"] = mock_ui
package.loaded["grapple.client.debugger"] = mock_debugger
package.loaded["conjure.editor"] = mock_editor
package.loaded["conjure.nfnl.string"] = mock_str
package.loaded["conjure.nfnl.core"] = n
local handler = require("grapple.client.handler")
local function _16_()
  local function _17_()
    log_calls = {}
    state_data = {conn = {}, breakpoints = {[123] = {bufnr = 1, ["file-path"] = "./test.janet", line = 10, ["bp-id"] = 0}}}
    editor_calls = {}
    ui_calls = {}
    debugger_calls = {}
    return nil
  end
  before_each(_17_)
  local function _18_()
    local msg = {op = "sess.new", sess = "test-session-123", ["janet/impl"] = {"janet", "1.37.0"}, ["janet/serv"] = {"grapple", "0.1.0"}}
    handler["handle-message"](msg, nil)
    assert.equals("test-session-123", state_data.conn.session)
    assert.equals(1, #log_calls)
    assert.equals("info", log_calls[1].sec)
    local lines = log_calls[1].lines
    local message = "Connected to Grapple v0.1.0 running Janet v1.37.0 as session test-session-123"
    assert.is_table(lines)
    assert.equals(1, #lines)
    return assert.equals(message, lines[1])
  end
  it("handles sess.new messages", _18_)
  local function _19_()
    local msg = {op = "env.eval", val = nil}
    handler["handle-message"](msg, nil)
    return assert.equals(0, #log_calls)
  end
  it("handles env.eval messages with nil value", _19_)
  local function _20_()
    local msg = {op = "env.eval", tag = "out", ch = "out", val = "Hello, world!"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("stdout", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Hello, world!", lines[1])
  end
  it("handles env.eval messages with stdout", _20_)
  local function _21_()
    local msg = {op = "env.eval", tag = "out", ch = "err", val = "Error occurred"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("stderr", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Error occurred", lines[1])
  end
  it("handles env.eval messages with stderr", _21_)
  local function _22_()
    local msg = {op = "env.eval", tag = "ret", val = "42"}
    handler["handle-message"](msg, {})
    assert.equals(1, #log_calls)
    assert.equals("result", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("42", lines[1])
  end
  it("handles env.eval messages with return value", _22_)
  local function _23_()
    local msg = {op = "env.eval", tag = "note", val = "Re-evaluating dependents of x: y, z"}
    handler["handle-message"](msg, {})
    assert.equals(1, #log_calls)
    assert.equals("note", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Re-evaluating dependents of x: y, z", lines[1])
  end
  it("handles env.eval messages with note", _23_)
  local function _24_()
    local msg = {op = "env.load", tag = "ret", val = "loaded"}
    handler["handle-message"](msg, {})
    assert.equals(1, #log_calls)
    return assert.equals("result", log_calls[1].sec)
  end
  it("handles env.load messages like env.eval", _24_)
  local function _25_()
    local msg = {op = "brk.add", tag = "ret", ["janet/bp-id"] = 0}
    local opts = {bufnr = 1, ["file-path"] = "./test.janet", line = 10}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("info", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Added breakpoint at ./test.janet:10", lines[1])
  end
  it("handles brk.add response", _25_)
  local function _26_()
    local msg = {op = "brk.rem", tag = "ret", ["janet/bp-id"] = 0}
    local opts = {["sign-id"] = 123}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("info", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Removed breakpoint at ./test.janet:10", lines[1])
  end
  it("handles brk.rem response", _26_)
  local function _27_()
    local msg = {op = "brk.clr", tag = "ret"}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("info", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Cleared all breakpoints", lines[1])
  end
  it("handles brk.clr response", _27_)
  local function _28_()
    local msg = {op = "brk.list", tag = "ret", val = "@[{:id 0 :path \"./test.janet\" :line 10}]"}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    return assert.equals("result", log_calls[1].sec)
  end
  it("handles brk.list response", _28_)
  local function _29_()
    local msg = {op = "env.eval", tag = "sig", val = "debug", ["janet/stack"] = {{name = "test-fn", source = "./test.janet", ["source-line"] = 10, pc = 5}}, ["janet/asm"] = "bytecode here...", req = "req-123"}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(1, #debugger_calls)
    return assert.equals(msg, debugger_calls[1].msg)
  end
  it("handles debug signal within env.eval", _29_)
  local function _30_()
    local msg = {tag = "err", val = "Compilation error", ["janet/path"] = "/path/to/file.janet", ["janet/line"] = 10, ["janet/col"] = 5}
    handler["handle-message"](msg, nil)
    assert.equals(2, #log_calls)
    assert.equals("error", log_calls[1].sec)
    assert.equals("error", log_calls[2].sec)
    local line1 = log_calls[1].lines
    local line2 = log_calls[2].lines
    local expected_location = " in /path/to/file.janet on line 10 at col 5"
    assert.equals("Compilation error", line1[1])
    return assert.equals(expected_location, line2[1])
  end
  it("handles error messages", _30_)
  local function _31_()
    local msg = {op = "unknown.op"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Unrecognised message", lines[1])
  end
  it("handles unrecognized messages", _31_)
  local function _32_()
    handler["handle-message"](nil, nil)
    return assert.equals(0, #log_calls)
  end
  return it("handles nil messages gracefully", _32_)
end
return describe("handle-message", _16_)

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
local mock_log
local function _2_(sec, lines)
  return table.insert(log_calls, {sec = sec, lines = lines})
end
mock_log = {append = _2_}
local mock_state
local function _3_(key)
  if key then
    return state_data[key]
  else
    return state_data
  end
end
mock_state = {get = _3_}
local mock_editor
local function _5_(path, line, col)
  return table.insert(editor_calls, {path = path, line = line, col = col})
end
mock_editor = {["go-to"] = _5_}
local mock_str
local function _6_(text, sep)
  local result = {}
  for part in string.gmatch(text, ("[^" .. sep .. "]+")) do
    table.insert(result, part)
  end
  return result
end
mock_str = {split = _6_}
local mock_ui
local function _7_(bufnr, file_path, line, bp_id)
  return table.insert(ui_calls, {op = "add", bufnr = bufnr, ["file-path"] = file_path, line = line, ["bp-id"] = bp_id})
end
local function _8_(sign_id)
  if (sign_id == 123) then
    return 10
  else
    return nil
  end
end
local function _10_(sign_id)
  return table.insert(ui_calls, {op = "remove", ["sign-id"] = sign_id})
end
local function _11_()
  return table.insert(ui_calls, {op = "clear"})
end
local function _12_(bufnr, file_path, line)
  return table.insert(ui_calls, {op = "show-debug", bufnr = bufnr, ["file-path"] = file_path, line = line})
end
local function _13_()
  return table.insert(ui_calls, {op = "hide-debug"})
end
mock_ui = {["add-breakpoint-sign"] = _7_, ["get-sign-current-line"] = _8_, ["remove-breakpoint-sign"] = _10_, ["clear-breakpoint-signs"] = _11_, ["show-debug-indicators"] = _12_, ["hide-debug-indicators"] = _13_}
local n = require("nfnl.core")
package.loaded["grapple.client.log"] = mock_log
package.loaded["grapple.client.state"] = mock_state
package.loaded["grapple.client.ui"] = mock_ui
package.loaded["conjure.editor"] = mock_editor
package.loaded["conjure.nfnl.string"] = mock_str
package.loaded["conjure.nfnl.core"] = n
local handler = require("grapple.client.handler")
local function _14_()
  local function _15_()
    log_calls = {}
    state_data = {conn = {}, breakpoints = {[123] = {bufnr = 1, ["file-path"] = "./test.janet", line = 10, ["bp-id"] = 0}}}
    editor_calls = {}
    ui_calls = {}
    return nil
  end
  before_each(_15_)
  local function _16_()
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
  it("handles sess.new messages", _16_)
  local function _17_()
    local msg = {op = "env.eval", val = nil}
    handler["handle-message"](msg, nil)
    return assert.equals(0, #log_calls)
  end
  it("handles env.eval messages with nil value", _17_)
  local function _18_()
    local msg = {op = "env.eval", tag = "out", ch = "out", val = "Hello, world!"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("stdout", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Hello, world!", lines[1])
  end
  it("handles env.eval messages with stdout", _18_)
  local function _19_()
    local msg = {op = "env.eval", tag = "out", ch = "err", val = "Error occurred"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("stderr", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Error occurred", lines[1])
  end
  it("handles env.eval messages with stderr", _19_)
  local function _20_()
    local msg = {op = "env.eval", tag = "ret", val = "42"}
    handler["handle-message"](msg, {})
    assert.equals(1, #log_calls)
    assert.equals("result", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("42", lines[1])
  end
  it("handles env.eval messages with return value", _20_)
  local function _21_()
    local msg = {op = "env.eval", tag = "note", val = "Re-evaluating dependents of x: y, z"}
    handler["handle-message"](msg, {})
    assert.equals(1, #log_calls)
    assert.equals("note", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Re-evaluating dependents of x: y, z", lines[1])
  end
  it("handles env.eval messages with note", _21_)
  local function _22_()
    local msg = {op = "env.load", tag = "ret", val = "loaded"}
    handler["handle-message"](msg, {})
    assert.equals(1, #log_calls)
    return assert.equals("result", log_calls[1].sec)
  end
  it("handles env.load messages like env.eval", _22_)
  local function _23_()
    local msg = {op = "dbg.brk.add", tag = "ret", ["janet/bp-id"] = 0}
    local opts = {bufnr = 1, ["file-path"] = "./test.janet", line = 10}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("debug", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Breakpoint added at ./test.janet:10", lines[1])
  end
  it("handles dbg.brk.add response", _23_)
  local function _24_()
    local msg = {op = "dbg.brk.rem", tag = "ret", ["janet/bp-id"] = 0}
    local opts = {["sign-id"] = 123}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("debug", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Breakpoint removed at ./test.janet:10", lines[1])
  end
  it("handles dbg.brk.rem response", _24_)
  local function _25_()
    local msg = {op = "dbg.brk.clr", tag = "ret"}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("debug", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("All breakpoints cleared", lines[1])
  end
  it("handles dbg.brk.clr response", _25_)
  local function _26_()
    local msg = {op = "dbg.insp.stk", tag = "ret", val = "Stack frame data..."}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("result", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Stack frame data...", lines[1])
  end
  it("handles dbg.insp.stk response with stack frames", _26_)
  local function _27_()
    local msg = {op = "dbg.insp.stk", tag = "ret"}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(1, #log_calls)
    assert.equals("debug", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("No stack frames available", lines[1])
  end
  it("handles dbg.insp.stk response without stack frames", _27_)
  local function _28_()
    local msg = {op = "env.eval", tag = "sig", val = "debug", ["janet/path"] = "./test.janet", ["janet/line"] = 10}
    local opts = {}
    handler["handle-message"](msg, opts)
    assert.equals(2, #log_calls)
    assert.equals("debug", log_calls[1].sec)
    assert.equals("debug", log_calls[2].sec)
    local line1 = log_calls[1].lines
    local line2 = log_calls[2].lines
    assert.equals("Paused at breakpoint at ./test.janet:10", line1[1])
    return assert.equals("Use <localleader>dis to inspect stack, <localleader>dsc to continue", line2[1])
  end
  it("handles debug signal within env.eval", _28_)
  local function _29_()
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
  it("handles error messages", _29_)
  local function _30_()
    local msg = {op = "unknown.op"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Unrecognised message", lines[1])
  end
  it("handles unrecognized messages", _30_)
  local function _31_()
    handler["handle-message"](nil, nil)
    return assert.equals(0, #log_calls)
  end
  return it("handles nil messages gracefully", _31_)
end
return describe("handle-message", _14_)

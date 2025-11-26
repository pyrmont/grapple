-- [nfnl] fnl/grapple-unit/client/handler_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local assert = require("luassert.assert")
local log_calls = {}
local state_data = {conn = {}}
local editor_calls = {}
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
local n = require("nfnl.core")
package.loaded["grapple.client.log"] = mock_log
package.loaded["grapple.client.state"] = mock_state
package.loaded["conjure.editor"] = mock_editor
package.loaded["conjure.nfnl.string"] = mock_str
package.loaded["conjure.nfnl.core"] = n
local handler = require("grapple.client.handler")
local function _7_()
  local function _8_()
    log_calls = {}
    state_data = {conn = {}}
    editor_calls = {}
    return nil
  end
  before_each(_8_)
  local function _9_()
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
  it("handles sess.new messages", _9_)
  local function _10_()
    local msg = {op = "env.eval", val = nil}
    handler["handle-message"](msg, nil)
    return assert.equals(0, #log_calls)
  end
  it("handles env.eval messages with nil value", _10_)
  local function _11_()
    local msg = {op = "env.eval", tag = "out", ch = "out", val = "Hello, world!"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("stdout", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Hello, world!", lines[1])
  end
  it("handles env.eval messages with stdout", _11_)
  local function _12_()
    local msg = {op = "env.eval", tag = "out", ch = "err", val = "Error occurred"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("stderr", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Error occurred", lines[1])
  end
  it("handles env.eval messages with stderr", _12_)
  local function _13_()
    local msg = {op = "env.eval", tag = "ret", val = "42"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("result", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("42", lines[1])
  end
  it("handles env.eval messages with return value", _13_)
  local function _14_()
    local msg = {op = "env.load", tag = "ret", val = "loaded"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    return assert.equals("result", log_calls[1].sec)
  end
  it("handles env.load messages like env.eval", _14_)
  local function _15_()
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
  it("handles error messages", _15_)
  local function _16_()
    local msg = {op = "unknown.op"}
    handler["handle-message"](msg, nil)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    return assert.equals("Unrecognised message", lines[1])
  end
  it("handles unrecognized messages", _16_)
  local function _17_()
    handler["handle-message"](nil, nil)
    return assert.equals(0, #log_calls)
  end
  return it("handles nil messages gracefully", _17_)
end
return describe("handle-message", _7_)

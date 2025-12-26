-- [nfnl] fnl/grapple-unit/client/request_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local after_each = _local_1_.after_each
local assert = require("luassert.assert")
local log_calls = {}
local mock_log
local function _2_(sec, lines)
  return table.insert(log_calls, {sec = sec, lines = lines})
end
mock_log = {append = _2_}
local original_log = package.loaded["grapple.client.log"]
package.loaded["grapple.client.log"] = mock_log
local request = require("grapple.client.request")
local function _3_()
  local function _4_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _5_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _5_}
    local opts
    local function _6_()
      return "test-action"
    end
    opts = {action = _6_}
    request["sess-new"](conn, opts)
    assert.equals("sess.new", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends sess.new message with action", _4_)
end
describe("sess-new", _3_)
local function _7_()
  local function _8_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _9_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _9_}
    local opts
    local function _10_()
      return "test-action"
    end
    opts = {action = _10_}
    request["sess-end"](conn, opts)
    assert.equals("sess.end", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  it("sends sess.end message with action", _8_)
  local function _11_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _12_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _12_}
    local opts = {}
    request["sess-end"](conn, opts)
    assert.equals("sess.end", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends sess.end message with nil action when opts has no action", _11_)
end
describe("sess-end", _7_)
local function _13_()
  local function _14_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _15_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _15_}
    local opts
    local function _16_()
      return "test-action"
    end
    opts = {action = _16_}
    request["sess-list"](conn, opts)
    assert.equals("sess.list", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends sess.list message with action", _14_)
end
describe("sess-list", _13_)
local function _17_()
  local function _18_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _19_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _19_}
    local opts
    local function _20_()
      return "test-action"
    end
    opts = {action = _20_}
    request["serv-info"](conn, opts)
    assert.equals("serv.info", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends serv.info message with action", _18_)
end
describe("serv-info", _17_)
local function _21_()
  local function _22_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _23_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _23_}
    local opts
    local function _24_()
      return "test-action"
    end
    opts = {action = _24_}
    request["serv-stop"](conn, opts)
    assert.equals("serv.stop", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends serv.stop message with action", _22_)
end
describe("serv-stop", _21_)
local function _25_()
  local function _26_()
    log_calls = {}
    return nil
  end
  before_each(_26_)
  local function _27_()
    local conn = {}
    local opts = {}
    request["serv-rest"](conn, opts)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    assert.equals(1, #lines)
    return assert.equals("serv.rest is not supported", lines[1])
  end
  return it("logs error that serv.rest is not supported", _27_)
end
describe("serv-rest", _25_)
local function _28_()
  local function _29_()
    log_calls = {}
    return nil
  end
  before_each(_29_)
  local function _30_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _31_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _31_}
    local opts
    local function _32_()
      return "test-action"
    end
    opts = {code = "(+ 1 2)", ["file-path"] = "/path/to/file.janet", range = {start = {10, 5}}, action = _32_}
    request["env-eval"](conn, opts)
    assert.equals("env.eval", sent_msg.op)
    assert.equals("(+ 1 2)", sent_msg.code)
    assert.equals("/path/to/file.janet", sent_msg.ns)
    assert.equals(10, sent_msg.line)
    assert.equals(5, sent_msg.col)
    assert.equals(opts, sent_opts)
    assert.equals(1, #log_calls)
    return assert.equals("input", log_calls[1].sec)
  end
  it("sends env.eval message with code and position", _30_)
  local function _33_()
    local sent_msg = nil
    local conn
    local function _34_(msg, action)
      sent_msg = msg
      return nil
    end
    conn = {send = _34_}
    local opts
    local function _35_()
      return "test-action"
    end
    opts = {code = "(print 'hello')", ["file-path"] = "/path/to/file.janet", action = _35_}
    request["env-eval"](conn, opts)
    assert.equals(1, sent_msg.line)
    return assert.equals(1, sent_msg.col)
  end
  it("uses default line and col when range not provided", _33_)
  local function _36_()
    local sent_msg = nil
    local conn
    local function _37_(msg, action)
      sent_msg = msg
      return nil
    end
    conn = {send = _37_}
    local opts
    local function _38_()
      return "test-action"
    end
    opts = {code = "(print 'hello')", ["file-path"] = "/path/to/file.janet", range = {start = {5}}, action = _38_}
    request["env-eval"](conn, opts)
    assert.equals(5, sent_msg.line)
    return assert.equals(1, sent_msg.col)
  end
  return it("uses default col when range has no start col", _36_)
end
describe("env-eval", _28_)
local function _39_()
  local function _40_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _41_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _41_}
    local opts
    local function _42_()
      return "test-action"
    end
    opts = {["file-path"] = "/path/to/file.janet", action = _42_}
    request["env-load"](conn, opts)
    assert.equals("env.load", sent_msg.op)
    assert.equals("/path/to/file.janet", sent_msg.path)
    return assert.equals(opts, sent_opts)
  end
  return it("sends env.load message with file path", _40_)
end
describe("env-load", _39_)
local function _43_()
  local function _44_()
    log_calls = {}
    return nil
  end
  before_each(_44_)
  local function _45_()
    local conn = {}
    local opts = {}
    request["env-stop"](conn, opts)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    assert.equals(1, #lines)
    return assert.equals("env.stop is not supported", lines[1])
  end
  return it("logs error that env.stop is not supported", _45_)
end
describe("env-stop", _43_)
local function _46_()
  local function _47_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _48_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _48_}
    local opts
    local function _49_()
      return "test-action"
    end
    opts = {code = "defn", ["file-path"] = "/path/to/file.janet", action = _49_}
    request["env-doc"](conn, opts)
    assert.equals("env.doc", sent_msg.op)
    assert.equals("defn", sent_msg.sym)
    assert.equals("/path/to/file.janet", sent_msg.ns)
    return assert.equals(opts, sent_opts)
  end
  return it("sends env.doc message with symbol and namespace", _47_)
end
describe("env-doc", _46_)
local function _50_()
  local function _51_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _52_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _52_}
    local opts
    local function _53_()
      return "test-action"
    end
    opts = {code = "def", ["file-path"] = "/path/to/file.janet", action = _53_}
    request["env-cmpl"](conn, opts)
    assert.equals("env.cmpl", sent_msg.op)
    assert.equals("def", sent_msg.sym)
    assert.equals("/path/to/file.janet", sent_msg.ns)
    return assert.equals(opts, sent_opts)
  end
  return it("sends env.cmpl message with symbol and namespace", _51_)
end
describe("env-cmpl", _50_)
package.loaded["grapple.client.log"] = original_log
return nil

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
  it("sends sess.new message with action", _4_)
  local function _7_()
    local state = require("grapple.client.state")
    local n = require("conjure.nfnl.core")
    n.assoc(state.get(), "token", "test-token-abc123")
    local sent_msg = nil
    local sent_opts = nil
    do
      local conn
      local function _8_(msg, opts)
        sent_msg = msg
        sent_opts = opts
        return nil
      end
      conn = {send = _8_}
      local opts
      local function _9_()
        return "test-action"
      end
      opts = {action = _9_}
      request["sess-new"](conn, opts)
      assert.equals("sess.new", sent_msg.op)
      assert.equals("test-token-abc123", sent_msg.auth)
      assert.equals(opts, sent_opts)
    end
    return n.assoc(state.get(), "token", nil)
  end
  it("sends sess.new message with auth token when token in state", _7_)
  local function _10_()
    local state = require("grapple.client.state")
    local n = require("conjure.nfnl.core")
    n.assoc(state.get(), "token", nil)
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _11_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _11_}
    local opts
    local function _12_()
      return "test-action"
    end
    opts = {action = _12_}
    request["sess-new"](conn, opts)
    assert.equals("sess.new", sent_msg.op)
    assert.is_nil(sent_msg.auth)
    return assert.equals(opts, sent_opts)
  end
  return it("sends sess.new message without auth when no token in state", _10_)
end
describe("sess-new", _3_)
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
    request["sess-end"](conn, opts)
    assert.equals("sess.end", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  it("sends sess.end message with action", _14_)
  local function _17_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _18_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _18_}
    local opts = {}
    request["sess-end"](conn, opts)
    assert.equals("sess.end", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends sess.end message with nil action when opts has no action", _17_)
end
describe("sess-end", _13_)
local function _19_()
  local function _20_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _21_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _21_}
    local opts
    local function _22_()
      return "test-action"
    end
    opts = {action = _22_}
    request["sess-list"](conn, opts)
    assert.equals("sess.list", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends sess.list message with action", _20_)
end
describe("sess-list", _19_)
local function _23_()
  local function _24_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _25_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _25_}
    local opts
    local function _26_()
      return "test-action"
    end
    opts = {action = _26_}
    request["serv-info"](conn, opts)
    assert.equals("serv.info", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends serv.info message with action", _24_)
end
describe("serv-info", _23_)
local function _27_()
  local function _28_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _29_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _29_}
    local opts
    local function _30_()
      return "test-action"
    end
    opts = {action = _30_}
    request["serv-stop"](conn, opts)
    assert.equals("serv.stop", sent_msg.op)
    return assert.equals(opts, sent_opts)
  end
  return it("sends serv.stop message with action", _28_)
end
describe("serv-stop", _27_)
local function _31_()
  local function _32_()
    log_calls = {}
    return nil
  end
  before_each(_32_)
  local function _33_()
    local conn = {}
    local opts = {}
    request["serv-rest"](conn, opts)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    assert.equals(1, #lines)
    return assert.equals("serv.rest is not supported", lines[1])
  end
  return it("logs error that serv.rest is not supported", _33_)
end
describe("serv-rest", _31_)
local function _34_()
  local function _35_()
    log_calls = {}
    return nil
  end
  before_each(_35_)
  local function _36_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _37_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _37_}
    local opts
    local function _38_()
      return "test-action"
    end
    opts = {code = "(+ 1 2)", ["file-path"] = "/path/to/file.janet", range = {start = {10, 5}}, action = _38_}
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
  it("sends env.eval message with code and position", _36_)
  local function _39_()
    local sent_msg = nil
    local conn
    local function _40_(msg, action)
      sent_msg = msg
      return nil
    end
    conn = {send = _40_}
    local opts
    local function _41_()
      return "test-action"
    end
    opts = {code = "(print 'hello')", ["file-path"] = "/path/to/file.janet", action = _41_}
    request["env-eval"](conn, opts)
    assert.equals(1, sent_msg.line)
    return assert.equals(1, sent_msg.col)
  end
  it("uses default line and col when range not provided", _39_)
  local function _42_()
    local sent_msg = nil
    local conn
    local function _43_(msg, action)
      sent_msg = msg
      return nil
    end
    conn = {send = _43_}
    local opts
    local function _44_()
      return "test-action"
    end
    opts = {code = "(print 'hello')", ["file-path"] = "/path/to/file.janet", range = {start = {5}}, action = _44_}
    request["env-eval"](conn, opts)
    assert.equals(5, sent_msg.line)
    return assert.equals(1, sent_msg.col)
  end
  return it("uses default col when range has no start col", _42_)
end
describe("env-eval", _34_)
local function _45_()
  local function _46_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _47_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _47_}
    local opts
    local function _48_()
      return "test-action"
    end
    opts = {["file-path"] = "/path/to/file.janet", action = _48_}
    request["env-load"](conn, opts)
    assert.equals("env.load", sent_msg.op)
    assert.equals("/path/to/file.janet", sent_msg.path)
    return assert.equals(opts, sent_opts)
  end
  return it("sends env.load message with file path", _46_)
end
describe("env-load", _45_)
local function _49_()
  local function _50_()
    log_calls = {}
    return nil
  end
  before_each(_50_)
  local function _51_()
    local conn = {}
    local opts = {}
    request["env-stop"](conn, opts)
    assert.equals(1, #log_calls)
    assert.equals("error", log_calls[1].sec)
    local lines = log_calls[1].lines
    assert.equals(1, #lines)
    return assert.equals("env.stop is not supported", lines[1])
  end
  return it("logs error that env.stop is not supported", _51_)
end
describe("env-stop", _49_)
local function _52_()
  local function _53_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _54_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _54_}
    local opts
    local function _55_()
      return "test-action"
    end
    opts = {code = "defn", ["file-path"] = "/path/to/file.janet", action = _55_}
    request["env-doc"](conn, opts)
    assert.equals("env.doc", sent_msg.op)
    assert.equals("defn", sent_msg.sym)
    assert.equals("/path/to/file.janet", sent_msg.ns)
    return assert.equals(opts, sent_opts)
  end
  return it("sends env.doc message with symbol and namespace", _53_)
end
describe("env-doc", _52_)
local function _56_()
  local function _57_()
    local sent_msg = nil
    local sent_opts = nil
    local conn
    local function _58_(msg, opts)
      sent_msg = msg
      sent_opts = opts
      return nil
    end
    conn = {send = _58_}
    local opts
    local function _59_()
      return "test-action"
    end
    opts = {code = "def", ["file-path"] = "/path/to/file.janet", action = _59_}
    request["env-cmpl"](conn, opts)
    assert.equals("env.cmpl", sent_msg.op)
    assert.equals("def", sent_msg.sym)
    assert.equals("/path/to/file.janet", sent_msg.ns)
    return assert.equals(opts, sent_opts)
  end
  return it("sends env.cmpl message with symbol and namespace", _57_)
end
describe("env-cmpl", _56_)
package.loaded["grapple.client.log"] = original_log
return nil

-- [nfnl] fnl/grapple-unit/remote_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local assert = require("luassert.assert")
local uuid_counter = 0
local log_calls = {}
local sock_writes = {}
local net_connect_opts = nil
local mock_uuid
local function _2_()
  uuid_counter = (uuid_counter + 1)
  return ("test-uuid-" .. uuid_counter)
end
mock_uuid = {v4 = _2_}
local mock_log
local function _3_(tag, data)
  return table.insert(log_calls, {tag = tag, data = data})
end
mock_log = {dbg = _3_}
local mock_client
local function _4_(f)
  return nil
end
local function _5_(f)
  return f
end
local function _6_(f)
  return f
end
mock_client = {schedule = _4_, ["schedule-wrap"] = _5_, wrap = _6_}
local mock_sock
local function _7_(self, data)
  return table.insert(sock_writes, data)
end
local function _8_(self, cb)
  return nil
end
mock_sock = {write = _7_, read_start = _8_}
local mock_net
local function _9_(opts)
  net_connect_opts = opts
  local function _10_()
    return nil
  end
  return {sock = mock_sock, destroy = _10_}
end
mock_net = {connect = _9_}
local mock_transport
local function _11_()
  local function _12_(chunk)
    return {}
  end
  return _12_
end
local function _13_(msg)
  return ("ENCODED:" .. vim.inspect(msg))
end
mock_transport = {["make-decode"] = _11_, encode = _13_}
local n = require("nfnl.core")
package.loaded["conjure.uuid"] = mock_uuid
package.loaded["conjure.log"] = mock_log
package.loaded["conjure.client"] = mock_client
package.loaded["conjure.net"] = mock_net
package.loaded["grapple.transport"] = mock_transport
package.loaded["conjure.nfnl.core"] = n
local remote = require("grapple.remote")
local function _14_()
  local function _15_()
    uuid_counter = 0
    log_calls = {}
    sock_writes = {}
    net_connect_opts = nil
    return nil
  end
  before_each(_15_)
  local function _16_()
    local conn
    local function _17_()
      return nil
    end
    local function _18_(err)
      return nil
    end
    local function _19_(err)
      return nil
    end
    local function _20_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _17_, ["on-failure"] = _18_, ["on-error"] = _19_, ["on-message"] = _20_})
    assert.is_function(conn.send)
    assert.is_function(conn.decode)
    assert.equals("janet", conn.lang)
    assert.is_table(conn.msgs)
    assert.is_table(conn.queue)
    assert.is_nil(conn.session)
    assert.equals(mock_sock, conn.sock)
    return assert.is_function(conn.destroy)
  end
  it("creates connection with initial structure", _16_)
  local function _21_()
    local function _22_()
      return nil
    end
    local function _23_(err)
      return nil
    end
    local function _24_(err)
      return nil
    end
    local function _25_(msg, action)
      return nil
    end
    remote.connect({host = "192.168.1.1", port = "8080", lang = "janet", ["on-success"] = _22_, ["on-failure"] = _23_, ["on-error"] = _24_, ["on-message"] = _25_})
    assert.equals("192.168.1.1", net_connect_opts.host)
    assert.equals("8080", net_connect_opts.port)
    return assert.is_function(net_connect_opts.cb)
  end
  it("calls net.connect with correct options", _21_)
  local function _26_()
    local conn
    local function _27_()
      return nil
    end
    local function _28_(err)
      return nil
    end
    local function _29_(err)
      return nil
    end
    local function _30_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _27_, ["on-failure"] = _28_, ["on-error"] = _29_, ["on-message"] = _30_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    local function _31_()
      return nil
    end
    conn.send(msg, _31_)
    return assert.equals("test-uuid-1", msg.id)
  end
  it("send adds UUID to message", _26_)
  local function _32_()
    local conn
    local function _33_()
      return nil
    end
    local function _34_(err)
      return nil
    end
    local function _35_(err)
      return nil
    end
    local function _36_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _33_, ["on-failure"] = _34_, ["on-error"] = _35_, ["on-message"] = _36_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    local function _37_()
      return nil
    end
    conn.send(msg, _37_)
    return assert.equals("janet", msg.lang)
  end
  it("send adds lang to message", _32_)
  local function _38_()
    local conn
    local function _39_()
      return nil
    end
    local function _40_(err)
      return nil
    end
    local function _41_(err)
      return nil
    end
    local function _42_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _39_, ["on-failure"] = _40_, ["on-error"] = _41_, ["on-message"] = _42_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    conn["session"] = "test-session-123"
    local function _43_()
      return nil
    end
    conn.send(msg, _43_)
    return assert.equals("test-session-123", msg.sess)
  end
  it("send adds session to message when session exists", _38_)
  local function _44_()
    local conn
    local function _45_()
      return nil
    end
    local function _46_(err)
      return nil
    end
    local function _47_(err)
      return nil
    end
    local function _48_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _45_, ["on-failure"] = _46_, ["on-error"] = _47_, ["on-message"] = _48_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    local function _49_()
      return nil
    end
    conn.send(msg, _49_)
    return assert.is_nil(msg.sess)
  end
  it("send does not add session when session is nil", _44_)
  local function _50_()
    local conn
    local function _51_()
      return nil
    end
    local function _52_(err)
      return nil
    end
    local function _53_(err)
      return nil
    end
    local function _54_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _51_, ["on-failure"] = _52_, ["on-error"] = _53_, ["on-message"] = _54_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    local action_fn
    local function _55_()
      return "test-action"
    end
    action_fn = _55_
    local opts = {action = action_fn}
    conn.send(msg, opts)
    local stored = conn.msgs["test-uuid-1"]
    assert.is_table(stored)
    assert.equals(msg, stored.msg)
    return assert.equals(opts, stored.opts)
  end
  it("send stores message and opts in msgs map", _50_)
  local function _56_()
    local conn
    local function _57_()
      return nil
    end
    local function _58_(err)
      return nil
    end
    local function _59_(err)
      return nil
    end
    local function _60_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _57_, ["on-failure"] = _58_, ["on-error"] = _59_, ["on-message"] = _60_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    local function _61_()
      return nil
    end
    conn.send(msg, _61_)
    assert.equals(1, #sock_writes)
    local pos = string.find(sock_writes[1], "ENCODED:", 1, true)
    return assert.is_not_nil(pos)
  end
  it("send writes encoded message to socket", _56_)
  local function _62_()
    local conn
    local function _63_()
      return nil
    end
    local function _64_(err)
      return nil
    end
    local function _65_(err)
      return nil
    end
    local function _66_(msg, opts)
      return nil
    end
    conn = remote.connect({host = "localhost", port = "9365", lang = "janet", ["on-success"] = _63_, ["on-failure"] = _64_, ["on-error"] = _65_, ["on-message"] = _66_})
    local msg = {op = "env.eval", code = "(+ 1 2)"}
    local function _67_()
      return nil
    end
    conn.send(msg, _67_)
    assert.is_true((#log_calls > 0))
    local found_send = false
    for _, call in ipairs(log_calls) do
      if ("send" == call.tag) then
        found_send = true
      else
      end
    end
    return assert.is_true(found_send)
  end
  return it("send logs debug information", _62_)
end
return describe("connect", _14_)

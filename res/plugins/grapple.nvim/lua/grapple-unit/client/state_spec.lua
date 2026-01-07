-- [nfnl] fnl/grapple-unit/client/state_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local n = require("conjure.nfnl.core")
local state = require("grapple.client.state")
local function _2_()
  local function _3_()
    local initial = state.get()
    assert.is_table(initial)
    return assert.is_nil(initial.conn)
  end
  it("returns the initial state", _3_)
  local function _4_()
    local conn = state.get("conn")
    return assert.is_nil(conn)
  end
  it("returns a specific key from state", _4_)
  local function _5_()
    n.assoc(state.get(), "conn", {host = "localhost", port = 5555})
    local conn = state.get("conn")
    assert.is_table(conn)
    assert.equals("localhost", conn.host)
    return assert.equals(5555, conn.port)
  end
  it("allows updating state with assoc", _5_)
  local function _6_()
    n.assoc(state.get(), "conn", {session = "test-session"})
    local conn1 = state.get("conn")
    local conn2 = state.get("conn")
    assert.equals("test-session", conn1.session)
    assert.equals("test-session", conn2.session)
    return assert.equals(conn1, conn2)
  end
  it("persists state across calls", _6_)
  local function _7_()
    n.assoc(state.get(), "server-pid", 12345)
    n.assoc(state.get(), "log-sec", "output")
    assert.equals(12345, state.get("server-pid"))
    return assert.equals("output", state.get("log-sec"))
  end
  it("allows storing different keys", _7_)
  local function _8_()
    local missing = state.get("does-not-exist")
    return assert.is_nil(missing)
  end
  it("returns nil for non-existent keys", _8_)
  local function _9_()
    n.assoc(state.get(), "conn", {host = "localhost", port = 5555})
    n.assoc(state.get("conn"), "session", "abc123")
    local conn = state.get("conn")
    assert.equals("localhost", conn.host)
    assert.equals(5555, conn.port)
    return assert.equals("abc123", conn.session)
  end
  it("can update nested connection properties", _9_)
  local function _10_()
    n.assoc(state.get(), "conn", {host = "localhost"})
    assert.is_table(state.get("conn"))
    n.assoc(state.get(), "conn", nil)
    return assert.is_nil(state.get("conn"))
  end
  it("can clear state by setting to nil", _10_)
  local function _11_()
    n.assoc(state.get(), "conn", {host = "localhost"})
    n.assoc(state.get(), "server-pid", 99999)
    n.assoc(state.get(), "conn", nil)
    assert.is_nil(state.get("conn"))
    return assert.equals(99999, state.get("server-pid"))
  end
  it("maintains separate keys independently", _11_)
  local function _12_()
    local initial = state.get()
    return assert.is_nil(initial.token)
  end
  it("has token field initialized to nil", _12_)
  local function _13_()
    n.assoc(state.get(), "token", "abc123token")
    do
      local token = state.get("token")
      assert.equals("abc123token", token)
    end
    n.assoc(state.get(), "token", nil)
    return assert.is_nil(state.get("token"))
  end
  it("can store and retrieve authentication token", _13_)
  local function _14_()
    n.assoc(state.get(), "breakpoints", {["./test.janet"] = {[10] = "bp-key-1", [20] = "bp-key-2"}})
    do
      local bps = state.get("breakpoints")
      assert.is_table(bps)
      assert.equals("bp-key-1", bps["./test.janet"][10])
      assert.equals("bp-key-2", bps["./test.janet"][20])
    end
    n.assoc(state.get(), "breakpoints", nil)
    return assert.is_nil(state.get("breakpoints"))
  end
  it("can store and retrieve breakpoints", _14_)
  local function _15_()
    n.assoc(state.get(), "debug-position", {path = "./test.janet", line = 15, col = 3})
    do
      local pos = state.get("debug-position")
      assert.is_table(pos)
      assert.equals("./test.janet", pos.path)
      assert.equals(15, pos.line)
      assert.equals(3, pos.col)
    end
    n.assoc(state.get(), "debug-position", nil)
    return assert.is_nil(state.get("debug-position"))
  end
  it("can store and retrieve debug position", _15_)
  local function _16_()
    n.assoc(state.get(), "original-signcol-hl", "NormalNC")
    do
      local hl = state.get("original-signcol-hl")
      assert.equals("NormalNC", hl)
    end
    n.assoc(state.get(), "original-signcol-hl", nil)
    return assert.is_nil(state.get("original-signcol-hl"))
  end
  return it("can store and retrieve original SignColumn highlight", _16_)
end
return describe("get", _2_)

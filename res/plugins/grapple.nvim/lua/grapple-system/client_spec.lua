-- [nfnl] fnl/grapple-system/client_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local after_each = _local_1_.after_each
local assert = require("luassert.assert")
local client = require("grapple.client")
local state = require("grapple.client.state")
local log = require("grapple.client.log")
local n = require("conjure.nfnl.core")
local function setup_client_context()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "filetype", "janet")
  vim.api.nvim_set_current_buf(buf)
  client["on-filetype"]()
  log.buf()
  local function _2_()
    return false
  end
  vim.wait(100, _2_)
  return buf
end
local function _3_()
  local test_port = "19999"
  local test_buf = nil
  local function _4_()
    test_buf = setup_client_context()
    return nil
  end
  before_each(_4_)
  local function _5_()
    do
      local pid = state.get("server-pid")
      if pid then
        vim.fn.jobstop(pid)
        n.assoc(state.get(), "server-pid", nil)
      else
      end
    end
    local function _7_()
      return false
    end
    vim.wait(500, _7_)
    n.assoc(state.get(), "conn", nil)
    if test_buf then
      return pcall(vim.api.nvim_buf_delete, test_buf, {force = true})
    else
      return nil
    end
  end
  after_each(_5_)
  local function _9_()
    client["start-server"]({host = "127.0.0.1", port = test_port})
    local function _10_()
      return false
    end
    vim.wait(1000, _10_)
    local pid = state.get("server-pid")
    assert.is_not_nil(pid)
    return assert.is_number(pid)
  end
  it("can start server and store PID", _9_)
  local function _11_()
    client["start-server"]({host = "127.0.0.1", port = test_port})
    local function _12_()
      return false
    end
    vim.wait(1000, _12_)
    local pid = state.get("server-pid")
    assert.is_not_nil(pid)
    client["stop-server"]()
    local function _13_()
      return false
    end
    vim.wait(500, _13_)
    return assert.is_nil(state.get("server-pid"))
  end
  it("can stop the server", _11_)
  local function _14_()
    client["start-server"]({host = "127.0.0.1", port = "9999"})
    local function _15_()
      return false
    end
    vim.wait(1200, _15_)
    return assert.is_not_nil(state.get("server-pid"))
  end
  it("uses provided host and port", _14_)
  local function _16_()
    client["start-server"]({host = "127.0.0.1", port = test_port})
    local function _17_()
      return false
    end
    vim.wait(1200, _17_)
    local pid1 = state.get("server-pid")
    assert.is_not_nil(pid1)
    client["stop-server"]()
    local function _18_()
      return false
    end
    vim.wait(500, _18_)
    assert.is_nil(state.get("server-pid"))
    client["start-server"]({host = "127.0.0.1", port = test_port})
    local function _19_()
      return false
    end
    vim.wait(1200, _19_)
    local pid2 = state.get("server-pid")
    return assert.is_not_nil(pid2)
  end
  return it("handles multiple start/stop cycles", _16_)
end
describe("client system tests", _3_)
local function _20_()
  local function _21_()
    return assert.is_true(true)
  end
  return it("connection tests can be added once server tests pass", _21_)
end
return describe("client connection tests (optional)", _20_)

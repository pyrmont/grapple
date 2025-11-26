-- [nfnl] fnl/grapple-unit/client/log_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local assert = require("luassert.assert")
local client_log = require("grapple.client.log")
local function get_extmarks(buf, ns)
  return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {details = true})
end
local function count_extmarks_with_hl(buf, ns, hl_group)
  local marks = get_extmarks(buf, ns)
  local matching = {}
  for _, mark in ipairs(marks) do
    local id = mark[1]
    local row = mark[2]
    local col = mark[3]
    local opts = mark[4]
    if (opts.hl_group == hl_group) then
      table.insert(matching, mark)
    else
    end
  end
  return #matching
end
local function get_buf_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end
local function _3_()
  local function _4_()
    local buf_num = client_log.buf()
    assert.is_number(buf_num)
    return assert.is_true(vim.api.nvim_buf_is_valid(buf_num))
  end
  return it("returns a buffer number", _4_)
end
describe("buf", _3_)
local function _5_()
  local function _6_()
    local buf_num = client_log.buf()
    local initial_line_count = vim.api.nvim_buf_line_count(buf_num)
    client_log.append("info", {"test message 1", "test message 2"}, {})
    local new_line_count = vim.api.nvim_buf_line_count(buf_num)
    return assert.is_true((new_line_count > initial_line_count))
  end
  it("appends lines to the log buffer", _6_)
  local function _7_()
    local buf_num = client_log.buf()
    local lines_before = get_buf_lines(buf_num)
    client_log.append("info", {"info message"}, {})
    local lines_after = get_buf_lines(buf_num)
    local new_lines = #lines_after
    assert.is_true((new_lines > #lines_before))
    local found_header = false
    for _, line in ipairs(lines_after) do
      if line:match("info") then
        found_header = true
      else
      end
    end
    return assert.is_true(found_header)
  end
  it("adds section headers when section changes", _7_)
  local function _9_()
    local buf_num = client_log.buf()
    client_log.append("stdout", {"first stdout"}, {})
    local lines_after_first = get_buf_lines(buf_num)
    local count_after_first = #lines_after_first
    client_log.append("stdout", {"second stdout"}, {})
    local lines_after_second = get_buf_lines(buf_num)
    local count_after_second = #lines_after_second
    return assert.equals((count_after_first + 1), count_after_second)
  end
  it("does not repeat headers for same section", _9_)
  local function _10_()
    local buf_num = client_log.buf()
    local ns = vim.api.nvim_create_namespace("grapple-log")
    client_log.append("info", {"highlighted info"}, {})
    return assert.is_true((count_extmarks_with_hl(buf_num, ns, "Title") > 0))
  end
  it("highlights info content with Title", _10_)
  local function _11_()
    local buf_num = client_log.buf()
    local ns = vim.api.nvim_create_namespace("grapple-log")
    client_log.append("error", {"error occurred"}, {})
    return assert.is_true((count_extmarks_with_hl(buf_num, ns, "ErrorMsg") > 0))
  end
  it("highlights error content with ErrorMsg", _11_)
  local function _12_()
    local buf_num = client_log.buf()
    local ns = vim.api.nvim_create_namespace("grapple-log")
    client_log.append("stdout", {"program output"}, {})
    return assert.is_true((count_extmarks_with_hl(buf_num, ns, "String") > 0))
  end
  it("highlights stdout content with String", _12_)
  local function _13_()
    local buf_num = client_log.buf()
    local ns = vim.api.nvim_create_namespace("grapple-log")
    client_log.append("stderr", {"warning output"}, {})
    return assert.is_true((count_extmarks_with_hl(buf_num, ns, "WarningMsg") > 0))
  end
  it("highlights stderr content with WarningMsg", _13_)
  local function _14_()
    local buf_num = client_log.buf()
    local ns = vim.api.nvim_create_namespace("grapple-log")
    local title_before = count_extmarks_with_hl(buf_num, ns, "Title")
    local string_before = count_extmarks_with_hl(buf_num, ns, "String")
    client_log.append("input", {"(+ 1 2)"}, {})
    local title_after = count_extmarks_with_hl(buf_num, ns, "Title")
    local string_after = count_extmarks_with_hl(buf_num, ns, "String")
    assert.equals(title_before, title_after)
    return assert.equals(string_before, string_after)
  end
  it("does not add highlights for input content", _14_)
  local function _15_()
    local buf_num = client_log.buf()
    local ns = vim.api.nvim_create_namespace("grapple-log")
    local title_before = count_extmarks_with_hl(buf_num, ns, "Title")
    local string_before = count_extmarks_with_hl(buf_num, ns, "String")
    local warning_before = count_extmarks_with_hl(buf_num, ns, "WarningMsg")
    local error_before = count_extmarks_with_hl(buf_num, ns, "ErrorMsg")
    client_log.append("result", {"42"}, {})
    local lines = get_buf_lines(buf_num)
    local result_found
    do
      local found = false
      for _, line in ipairs(lines) do
        found = (found or (nil ~= line:match("42")))
      end
      result_found = found
    end
    assert.is_true(result_found)
    assert.equals(title_before, count_extmarks_with_hl(buf_num, ns, "Title"))
    assert.equals(string_before, count_extmarks_with_hl(buf_num, ns, "String"))
    assert.equals(warning_before, count_extmarks_with_hl(buf_num, ns, "WarningMsg"))
    return assert.equals(error_before, count_extmarks_with_hl(buf_num, ns, "ErrorMsg"))
  end
  return it("does not add highlights for result content", _15_)
end
return describe("append", _5_)

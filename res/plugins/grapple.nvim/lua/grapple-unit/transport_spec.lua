-- [nfnl] fnl/grapple-unit/transport_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local transport = require("grapple.transport")
local function _2_()
  local function _3_()
    local msg = {op = "sess.new"}
    local encoded = transport.encode(msg)
    assert.is_true((#encoded > 4))
    local b0 = string.byte(encoded, 1)
    local b1 = string.byte(encoded, 2)
    local b2 = string.byte(encoded, 3)
    local b3 = string.byte(encoded, 4)
    local len = (b0 + bit.lshift(b1, 8) + bit.lshift(b2, 16) + bit.lshift(b3, 24))
    local body = string.sub(encoded, 5)
    assert.equals(len, #body)
    local decoded = vim.json.decode(body)
    return assert.equals("sess.new", decoded.op)
  end
  it("encodes a simple message", _3_)
  local function _4_()
    local msg = {op = "env.eval", code = "(+ 1 2)", line = 1, col = 1}
    local encoded = transport.encode(msg)
    local body = string.sub(encoded, 5)
    local decoded = vim.json.decode(body)
    assert.equals("env.eval", decoded.op)
    assert.equals("(+ 1 2)", decoded.code)
    assert.equals(1, decoded.line)
    return assert.equals(1, decoded.col)
  end
  it("encodes a message with multiple fields", _4_)
  local function _5_()
    local msg = {op = "test", data = {nested = {value = 42}}}
    local encoded = transport.encode(msg)
    local body = string.sub(encoded, 5)
    local decoded = vim.json.decode(body)
    assert.equals("test", decoded.op)
    return assert.equals(42, decoded.data.nested.value)
  end
  it("encodes a message with nested data", _5_)
  local function _6_()
    local msg = {}
    local encoded = transport.encode(msg)
    return assert.is_true((#encoded >= 4))
  end
  return it("handles empty message", _6_)
end
describe("encode", _2_)
local function _7_()
  local function _8_()
    local decode = transport["make-decode"]()
    local msg = {op = "sess.new"}
    local encoded = transport.encode(msg)
    local decoded = decode(encoded)
    assert.equals(1, #decoded)
    return assert.equals("sess.new", decoded[1].op)
  end
  it("decodes a single complete message", _8_)
  local function _9_()
    local decode = transport["make-decode"]()
    local msg1 = {op = "sess.new"}
    local msg2 = {op = "env.eval", code = "(+ 1 2)"}
    local encoded = (transport.encode(msg1) .. transport.encode(msg2))
    local decoded = decode(encoded)
    assert.equals(2, #decoded)
    assert.equals("sess.new", decoded[1].op)
    assert.equals("env.eval", decoded[2].op)
    return assert.equals("(+ 1 2)", decoded[2].code)
  end
  it("decodes multiple messages in one chunk", _9_)
  local function _10_()
    local decode = transport["make-decode"]()
    local msg = {op = "sess.new"}
    local encoded = transport.encode(msg)
    local part = string.sub(encoded, 1, 4)
    local decoded = decode(part)
    return assert.equals(0, #decoded)
  end
  it("handles partial message - header only", _10_)
  local function _11_()
    local decode = transport["make-decode"]()
    local msg = {op = "sess.new"}
    local encoded = transport.encode(msg)
    local part = string.sub(encoded, 1, 8)
    local decoded = decode(part)
    return assert.equals(0, #decoded)
  end
  it("handles partial message - header + partial body", _11_)
  local function _12_()
    local decode = transport["make-decode"]()
    local msg = {op = "sess.new"}
    local encoded = transport.encode(msg)
    local mid = math.floor((#encoded / 2))
    local part1 = string.sub(encoded, 1, mid)
    local part2 = string.sub(encoded, (mid + 1))
    do
      local decoded1 = decode(part1)
      assert.equals(0, #decoded1)
    end
    local decoded2 = decode(part2)
    assert.equals(1, #decoded2)
    return assert.equals("sess.new", decoded2[1].op)
  end
  it("completes partial message with second chunk", _12_)
  local function _13_()
    local decode = transport["make-decode"]()
    local msg = {op = "test", value = 123}
    local encoded = transport.encode(msg)
    local header = string.sub(encoded, 1, 4)
    local body = string.sub(encoded, 5)
    assert.equals(0, #decode(header))
    local results = decode(body)
    assert.equals(1, #results)
    assert.equals("test", results[1].op)
    return assert.equals(123, results[1].value)
  end
  it("handles message split at 4-byte boundaries", _13_)
  local function _14_()
    local decode = transport["make-decode"]()
    local msg1 = {op = "first"}
    local msg2 = {op = "second"}
    local msg3 = {op = "third"}
    local encoded1 = transport.encode(msg1)
    local encoded2 = transport.encode(msg2)
    local encoded3 = transport.encode(msg3)
    local combined = (encoded1 .. encoded2 .. string.sub(encoded3, 1, 5))
    do
      local decoded = decode(combined)
      assert.equals(2, #decoded)
      assert.equals("first", decoded[1].op)
      assert.equals("second", decoded[2].op)
    end
    local rest = string.sub(encoded3, 6)
    local decoded = decode(rest)
    assert.equals(1, #decoded)
    return assert.equals("third", decoded[1].op)
  end
  it("handles multiple complete messages with partial", _14_)
  local function _15_()
    local decode = transport["make-decode"]()
    local msg1 = {op = "first"}
    local msg2 = {op = "second"}
    local encoded1 = transport.encode(msg1)
    local encoded2 = transport.encode(msg2)
    local combined = (encoded1 .. encoded2)
    do
      local decoded1 = decode(encoded1)
      assert.equals(1, #decoded1)
      assert.equals("first", decoded1[1].op)
    end
    local decoded2 = decode(encoded2)
    assert.equals(1, #decoded2)
    return assert.equals("second", decoded2[1].op)
  end
  it("handles exact boundary splits", _15_)
  local function _16_()
    local decode = transport["make-decode"]()
    local large_data = string.rep("x", 10000)
    local msg = {op = "large", data = large_data}
    local encoded = transport.encode(msg)
    local decoded = decode(encoded)
    assert.equals(1, #decoded)
    assert.equals("large", decoded[1].op)
    return assert.equals(10000, #decoded[1].data)
  end
  it("handles large message", _16_)
  local function _17_()
    local decode = transport["make-decode"]()
    local msg = {op = "test"}
    local encoded = transport.encode(msg)
    local len = #encoded
    local part1 = string.sub(encoded, 1, 4)
    local part2 = string.sub(encoded, 5, 6)
    local part3 = string.sub(encoded, 7)
    assert.equals(0, #decode(part1))
    assert.equals(0, #decode(part2))
    local result = decode(part3)
    assert.equals(1, #result)
    return assert.equals("test", result[1].op)
  end
  it("maintains state across calls", _17_)
  local function _18_()
    local decode = transport["make-decode"]()
    local msg = {op = "complex", data = {array = {1, 2, 3}, nested = {a = "hello", b = {c = {4, 5, 6}}}}}
    local encoded = transport.encode(msg)
    local decoded = decode(encoded)
    assert.equals(1, #decoded)
    local result = decoded[1]
    assert.equals("complex", result.op)
    assert.equals(1, result.data.array[1])
    assert.equals(2, result.data.array[2])
    assert.equals(3, result.data.array[3])
    assert.equals("hello", result.data.nested.a)
    return assert.equals(4, result.data.nested.b.c[1])
  end
  it("handles complex nested structures", _18_)
  local function _19_()
    local decode = transport["make-decode"]()
    local msg = {op = "test"}
    local encoded = transport.encode(msg)
    local decoded1 = decode(encoded)
    local decoded2 = decode(encoded)
    assert.equals(1, #decoded1)
    assert.equals(1, #decoded2)
    assert.equals("test", decoded1[1].op)
    return assert.equals("test", decoded2[1].op)
  end
  return it("handles empty array accumulator correctly", _19_)
end
describe("make-decode", _7_)
local function _20_()
  local function _21_()
    local decode = transport["make-decode"]()
    local original = {op = "env.eval", code = "(+ 1 2)", line = 1, col = 5, sess = "abc123"}
    local encoded = transport.encode(original)
    local decoded = decode(encoded)
    local result = decoded[1]
    assert.equals(original.op, result.op)
    assert.equals(original.code, result.code)
    assert.equals(original.line, result.line)
    assert.equals(original.col, result.col)
    return assert.equals(original.sess, result.sess)
  end
  return it("encode then decode returns original message", _21_)
end
return describe("round-trip", _20_)

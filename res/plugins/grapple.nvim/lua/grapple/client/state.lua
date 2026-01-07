-- [nfnl] fnl/grapple/client/state.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_.autoload
local client = autoload("conjure.client")
local get
local function _2_()
  return {conn = nil, ["server-pid"] = nil, ["server-port"] = nil, token = nil, breakpoints = {}, ["debug-position"] = nil, ["original-signcol-hl"] = nil, ["server-ready"] = false}
end
get = client["new-state"](_2_)
return {get = get}

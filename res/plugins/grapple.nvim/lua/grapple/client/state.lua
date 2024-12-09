-- [nfnl] Compiled from fnl/grapple/client/state.fnl by https://github.com/Olical/nfnl, do not edit.
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local client = autoload("conjure.client")
local get
local function _2_()
  return {conn = nil}
end
get = client["new-state"](_2_)
return {get = get}

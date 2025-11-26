-- [nfnl] fnl/grapple/remote.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_["autoload"]
local n = autoload("conjure.nfnl.core")
local client = autoload("conjure.client")
local log = autoload("conjure.log")
local net = autoload("conjure.net")
local trn = autoload("grapple.transport")
local uuid = autoload("conjure.uuid")
local function connect(opts)
  local conn = {decode = trn["make-decode"](), lang = opts.lang, msgs = {}, queue = {}, session = nil}
  local function send(msg, action)
    local id = uuid.v4()
    n.assoc(msg, "id", id, "lang", conn.lang)
    if conn.session then
      n.assoc(msg, "sess", conn.session)
    else
    end
    n["assoc-in"](conn, {"msgs", id}, {msg = msg, action = action})
    log.dbg("send", msg)
    return conn.sock:write(trn.encode(msg))
  end
  local function process_message(err, chunk)
    if (err or not chunk) then
      return opts["on-error"](err)
    else
      local function _3_(msg)
        log.dbg("receive", msg)
        local id = msg.req
        local action = n["get-in"](conn, {"msgs", id, "action"})
        return opts["on-message"](msg, action)
      end
      return n["run!"](_3_, conn.decode(chunk))
    end
  end
  local function process_queue()
    conn["awaiting-process?"] = false
    if not n["empty?"](conn.queue) then
      local msgs = conn.queue
      conn.queue = {}
      local function _5_(args)
        return process_message(unpack(args))
      end
      return n["run!"](_5_, msgs)
    else
      return nil
    end
  end
  local function enqueue_message(...)
    table.insert(conn.queue, {...})
    if not conn["awaiting-process?"] then
      conn["awaiting-process?"] = true
      return client.schedule(process_queue)
    else
      return nil
    end
  end
  local function handle_connect()
    local function _8_(err)
      log.dbg("handle-connect", err)
      if err then
        return opts["on-failure"](err)
      else
        opts["on-success"]()
        return conn.sock:read_start(client.wrap(enqueue_message))
      end
    end
    return client["schedule-wrap"](_8_)
  end
  conn = n.merge(conn, {send = send}, net.connect({host = opts.host, port = opts.port, cb = handle_connect()}))
  return conn
end
return {connect = connect}

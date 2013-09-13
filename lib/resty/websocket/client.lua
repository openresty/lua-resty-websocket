-- Copyright (C) 2013 Yichun Zhang (agentzh)


-- FIXME: this library is very rough and is currently just for testing
--        the websocket server.


local wbproto = require "resty.websocket.protocol"
local bit = require "bit"


local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame
local tcp = ngx.socket.tcp
local re_match = ngx.re.match
local encode_base64 = ngx.encode_base64
local concat = table.concat
local char = string.char
local rand = math.random
local rshift = bit.rshift
local band = bit.band


local _M = {
    _VERSION = '0.01'
}

local mt = { __index = _M }


function _M.new(self, opts)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end

    local max_payload_len
    if opts then
        max_payload_len = opts.max_payload_len
    end

    local send_unmasked
    if opts then
        send_unmasked = opts.send_unmasked
    end

    return setmetatable({
        sock = sock,
        max_payload_len = max_payload_len or 65535,
        send_unmasked = send_unmasked,
    }, mt)
end


function _M.connect(self, uri, opts)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local m, err = re_match(uri, [[^ws://([^:/]+)(?::(\d+))?(.*)]], "jo")
    if not m then
        if err then
            return nil, "failed to match the uri: " .. err
        end

        return nil, "bad websocket uri"
    end

    local host = m[1]
    local port = m[2]
    local path = m[3]

    -- ngx.say("host: ", host)
    -- ngx.say("port: ", port)

    if not port then
        port = 80
    end

    if path == "" then
        path = "/"
    end

    local proto_header

    if opts then
        local protos = opts.protocols
        if protos then
            if type(protos) == "table" then
                proto_header = "Sec-WebSocket-Protocol: "
                               .. concat(protos, ",") .. "\r\n"

            else
                proto_header = "Sec-WebSocket-Protocol: " .. protos .. "\r\n"
            end
        end
    end

    if not proto_header then
        proto_header = ""
    end

    local ok, err = sock:connect(host, port)
    if not ok then
        return nil, "failed to connect: " .. err
    end

    -- do the websocket handshake:

    local bytes = char(rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1, rand(256) - 1, rand(256) - 1,
                       rand(256) - 1)

    local key = encode_base64(bytes)
    local req = "GET " .. path .. " HTTP/1.1\r\nUpgrade: websocket\r\nHost: "
                .. host .. ":" .. port
                .. "\r\nSec-WebSocket-Key: " .. key
                .. proto_header
                .. "\r\nSec-WebSocket-Version: 13"
                .. "\r\nConnection: Upgrade\r\n\r\n"

    local bytes, err = sock:send(req)
    if not bytes then
        return nil, "failed to send the handshake request: " .. err
    end

    local header_reader = sock:receiveuntil("\r\n\r\n")
    -- FIXME: check for too big response headers
    local header, err = header_reader()
    if not header then
        return nil, "failed to receive response header"
    end

    -- FIXME: verify the response headers

    m, err = re_match(header, [[^\s*HTTP/1\.1\s+]], "jo")
    if not m then
        return nil, "bad HTTP response status line: " .. header
    end

    return 1
end


function _M.recv_frame(self)
    if self.fatal then
        return nil, nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    local data, typ, err =  _recv_frame(sock, self.max_payload_len, false)
    if not data then
        self.fatal = true
    end
    return data, typ, err
end


local function send_frame(self, fin, opcode, payload, max_payload_len)
    if self.fatal then
        return nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized yet"
    end

    local bytes, err = _send_frame(sock, fin, opcode, payload,
                                   self.max_payload_len,
                                   not self.send_unmasked)
    if not bytes then
        self.fatal = true
    end
    return bytes, err
end
_M.send_frame = send_frame


function _M.send_text(self, data)
    return send_frame(self, true, 0x1, data)
end


function _M.send_binary(self, data)
    return send_frame(self, true, 0x2, data)
end


function _M.send_close(self, code, msg)
    local payload
    if code then
        if type(code) ~= "number" or code > 0x7fff then
        end
        payload = char(band(rshift(code, 8), 0xff), band(code, 0xff))
                        .. (msg or "")
    end
    return send_frame(self, true, 0x8, payload)
end


function _M.send_ping(self, data)
    return send_frame(self, true, 0x9, data)
end


function _M.send_pong(self, data)
    return send_frame(self, true, 0xa, data)
end


return _M
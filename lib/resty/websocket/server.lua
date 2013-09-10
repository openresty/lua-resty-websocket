-- Copyright (C) 2013 Yichun Zhang (agentzh)


local bit = require "bit"

local http_ver = ngx.req.http_version
local req_sock = ngx.req.socket
local ngx_header = ngx.header
local req_headers = ngx.req.get_headers
local str_lower = string.lower
local str_char = string.char
local byte = string.byte
local sha1_bin = ngx.sha1_bin
local base64 = ngx.encode_base64
local ngx = ngx
local read_body = ngx.req.read_body
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local tohex = bit.tohex
local print = print
local concat = table.concat


local _M = {
    _VERSION = '0.01'
}

local mt = { __index = _M }

local types = {
    [0x1] = "text",
    [0x2] = "binary",
    [0x8] = "close",
    [0x9] = "ping",
    [0xa] = "pong",
}


function _M.new(self, opts)
    if ngx.headers_sent then
        return nil, "response header already sent"
    end

    read_body()

    if http_ver() ~= 1.1 then
        return nil, "bad http version"
    end

    local headers = req_headers()

    local val = headers.upgrade
    if type(val) == "table" then
        val = val[1]
    end
    if not val or str_lower(val) ~= "websocket" then
        return nil, "bad \"upgrade\" request header"
    end

    val = headers.connection
    if type(val) == "table" then
        val = val[1]
    end
    if not val or str_lower(val) ~= "upgrade" then
        return nil, "bad \"connection\" request header"
    end

    local key = headers["sec-websocket-key"]
    if type(key) == "table" then
        key = key[1]
    end
    if not key then
        return nil, "bad \"sec-websocket-key\" request header"
    end

    local ver = headers["sec-websocket-version"]
    if type(ver) == "table" then
        ver = ver[1]
    end
    if not ver or ver ~= "13" then
        return nil, "bad \"sec-websocket-version\" request header"
    end

    local protocols = headers["sec-websocket-protocol"]
    if type(protocols) == "table" then
        protocols = protocols[1]
    end

    if protocols then
        ngx_header["Sec-WebSocket-Protocol"] = protocols
    end
    ngx_header["Upgrade"] = "websocket"

    local sha1 = sha1_bin(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    ngx_header["Sec-WebSocket-Accept"] = base64(sha1)

    ngx.status = 101
    local ok, err = ngx.send_headers()
    if not ok then
        return nil, "failed to send response header: " .. (err or "unknonw")
    end
    ok, err = ngx.flush(true)
    if not ok then
        return nil, "failed to flush response header: " .. (err or "unknown")
    end

    local sock
    sock, err = req_sock(true)
    if not sock then
        return nil, err
    end

    local max_msg_len

    if opt then
        max_msg_len = opt.max_msg_len or 8192
    end

    return setmetatable({
        sock = sock,
        max_msg_len = max_msg_len,
    }, mt)
end


function _M.recv_frame(self)
    if self.fatal then
        return nil, nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    local data, err = sock:receive(2)
    if not data then
        self.fatal = true
        return nil, nil, "failed to receive the first 2 bytes: " .. (err or "unknown")
    end

    local fst, snd = byte(data, 1, 2)

    local fin = band(fst, 0x80) ~= 0
    -- print("fin: ", fin)

    if band(fst, 0x70) ~= 0 then
        self.fatal = true
        return nil, nil, "bad RSV1, RSV2, or RSV3 bits"
    end

    local opcode = band(fst, 0x0f)
    -- print("opcode: ", tohex(opcode))

    if opcode >= 0x3 and opcode <= 0x7 then
        self.fatal = true
        return nil, nil, "reserved non-control frames"
    end

    if opcode >= 0xb and opcode <= 0xf then
        self.fatal = true
        return nil, nil, "reserved control frames"
    end

    local mask = band(snd, 0x80) ~= 0
    -- print("mask bit: ", mask)
    if not mask then
        self.fatal = true
        return nil, nil, "frame unmasked"
    end

    local payload_len = band(snd, 0x7f)
    -- print("payload len: ", payload_len)

    local rest
    if payload_len == 126 then
        local data, err = sock:receive(2)
        if not data then
            self.fatal = true
            return nil, nil, "failed to receive the 2 byte payload length: "
                             .. (err or "unknown")
        end

        payload_len = bor(lshift(byte(data, 1), 8), byte(data, 2))

    elseif payload_len == 127 then
        local data, err = sock:receive(8)
        if not data then
            self.fatal = true
            return nil, nil, "failed to receive the 8 byte payload length: "
                             .. (err or "unknown")
        end

        local fst = byte(data, 1)
        if band(fst, 0x80) ~= 0 then
            self.fatal = true
            return nil, nil, "payload len too large"
        end

        payload_len = bor(lshift(fst, 56),
                          lshift(byte(data, 2), 48),
                          lshift(byte(data, 3), 40),
                          lshift(byte(data, 4), 32),
                          lshift(byte(data, 5), 24),
                          lshift(byte(data, 6), 16),
                          lshift(byte(data, 7), 8),
                          byte(data, 8))
    end

    if band(opcode, 0x8) ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            self.fatal = true
            return nil, nil, "too long payload for control frame"
        end

        if not fin then
            self.fatal = true
            return nil, nil, "fragmented control frame"
        end
    end

    rest = payload_len + 4

    local data, err = sock:receive(rest)
    if not data then
        self.fatal = true
        return nil, nil, "failed to read masking-len and payload: "
                         .. (err or "unknown")
    end

    local payload

    if opcode == 0x8 then
        -- being a close frame
        if payload_len > 0 then
            if payload_len < 2 then
                return nil, nil, "close frame with a body must carry a 2-byte"
                                 .. " status code"
            end

            local fst = bxor(byte(data, 4 + 1), byte(data, 1))
            local snd = bxor(byte(data, 4 + 2), byte(data, 2))
            local code = bor(lshift(fst, 8), snd)

            local msg
            if payload_len > 2 then
                local bytes = {}  -- XXX table.new() or even string.buffer optimizations
                for i = 3, payload_len do
                    bytes[i - 2] = str_char(bxor(byte(data, 4 + i), byte(data, (i - 1) % 4 + 1)))
                end
                msg = concat(bytes)
            end

            return code, "close", msg
        end

        return nil, "close", nil

    else

        local bytes = {}  -- XXX table.new() or even string.buffer optimizations
        for i = 1, payload_len do
            bytes[i] = str_char(bxor(byte(data, 4 + i), byte(data, (i - 1) % 4 + 1)))
        end

        return concat(bytes), types[opcode]
    end
end


return _M

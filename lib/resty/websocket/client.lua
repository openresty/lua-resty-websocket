-- Copyright (C) Yichun Zhang (agentzh)


-- FIXME: this library is very rough and is currently just for testing
--        the websocket client.


local wbproto = require "resty.websocket.protocol"
local bit = require "bit"


local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame
local new_tab = wbproto.new_tab
local tcp = ngx.socket.tcp
local re_match = ngx.re.match
local re_find  = ngx.re.find
local encode_base64 = ngx.encode_base64
local concat = table.concat
local char = string.char
local str_find = string.find
local rand = math.random
local rshift = bit.rshift
local band = bit.band
local setmetatable = setmetatable
local type = type
local debug = ngx.config.debug
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local assert = assert
local ssl_support = true

if not ngx.config
    or not ngx.config.ngx_lua_version
    or ngx.config.ngx_lua_version < 9011
then
    ssl_support = false
end

local _M = new_tab(0, 13)
_M._VERSION = '0.12'


local mt = { __index = _M }


function _M.new(self, opts)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end

    local max_payload_len, send_unmasked, timeout
    local max_recv_len, max_send_len
    if opts then
        max_payload_len = opts.max_payload_len
        max_recv_len = opts.max_recv_len
        max_send_len = opts.max_send_len

        send_unmasked = opts.send_unmasked
        timeout = opts.timeout

        if timeout then
            sock:settimeout(timeout)
        end
    end

    max_payload_len = max_payload_len or 65535
    max_recv_len = max_recv_len or max_payload_len
    max_send_len = max_send_len or max_payload_len

    return setmetatable({
        sock = sock,
        max_recv_len = max_recv_len,
        max_send_len = max_send_len,
        send_unmasked = send_unmasked,
    }, mt)
end


function _M.connect(self, uri, opts)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local is_unix = false

    local m, err
    if re_find(uri, "unix:") then
        is_unix = true
        m, err = re_match(uri, [[^(wss?)://(unix:[^:]+):()(.*)]], "jo")
    else
        m, err = re_match(uri, [[^(wss?)://([^:/]+)(?::(\d+))?(.*)]], "jo")
    end

    if not m then
        if err then
            return nil, "failed to match the uri: " .. err
        end

        return nil, "bad websocket uri"
    end

    local scheme = m[1]
    local addr = m[2]
    local port = m[3]
    local path = m[4]

    -- ngx.say("host: ", host)
    -- ngx.say("port: ", port)

    local ssl = scheme == "wss"
    if ssl and not ssl_support then
        return nil, "ngx_lua 0.9.11+ required for SSL sockets"
    end

    if not port then
        port = ssl and 443 or 80
    end

    if path == "" then
        path = "/"
    end

    local ssl_verify, server_name, headers, proto_header, origin_header
    local sock_opts = {}
    local client_cert, client_priv_key
    local header_host
    local key

    if opts then
        local protos = opts.protocols
        if protos then
            if type(protos) == "table" then
                proto_header = "\r\nSec-WebSocket-Protocol: "
                               .. concat(protos, ",")

            else
                proto_header = "\r\nSec-WebSocket-Protocol: " .. protos
            end
        end

        local origin = opts.origin
        if origin then
            origin_header = "\r\nOrigin: " .. origin
        end

        if opts.pool then
            sock_opts.pool = opts.pool
        end
        --pool_size specify the size of the connection pool. If omitted and no backlog option was provided, no pool will be created.
        if opts.pool_size then
            sock_opts.pool_size = opts.pool_size
        end
        if opts.backlog then
            sock_opts.backlog = opts.backlog
        end


        client_cert = opts.client_cert
        client_priv_key = opts.client_priv_key

        if client_cert then
            assert(client_priv_key,
                   "client_priv_key must be provided with client_cert")
        end

        ssl_verify = opts.ssl_verify

        server_name = opts.server_name
        if server_name ~= nil and type(server_name) ~= "string" then
            return nil, "SSL server_name must be a string"
        end

        if opts.headers then
            headers = opts.headers
            if type(headers) ~= "table" then
                return nil, "custom headers must be a table"
            end
        end

        header_host = opts.host
        if header_host ~= nil and type(header_host) ~= "string" then
            return nil, "custom host header must be a string"
        end

        key = opts.key
        if key ~= nil and type(key) ~= "string" then
            return nil, "custom Sec-WebSocket-Key must be a string"
        end
    end

    local ok, err
    if is_unix then
        ok, err = sock:connect(addr, sock_opts)
    else
        ok, err = sock:connect(addr, port, sock_opts)
    end
    if not ok then
        return nil, "failed to connect: " .. err
    end

    -- check for connections from pool:
    local reused_count, err = sock:getreusedtimes()
    if not reused_count then
        return nil, "failed to get reused times: " .. tostring(err)
    end

    if reused_count > 0 then
        -- being a reused connection (must have done handshake)
        return 1, nil, "connection reused"
    end

    if ssl then
        if client_cert then
            ok, err = sock:setclientcert(client_cert, client_priv_key)
            if not ok then
                return nil, "failed to set TLS client certificate: " .. err
            end
        end

        server_name = server_name or header_host or addr

        ok, err = sock:sslhandshake(false, server_name, ssl_verify)
        if not ok then
            return nil, "ssl handshake failed: " .. err
        end
    end

    local custom_headers
    if headers then
        custom_headers = concat(headers, "\r\n")
        custom_headers = "\r\n" .. custom_headers
    end

    -- do the websocket handshake:

    if not key then
        local bytes = char(rand(256) - 1, rand(256) - 1, rand(256) - 1,
                           rand(256) - 1, rand(256) - 1, rand(256) - 1,
                           rand(256) - 1, rand(256) - 1, rand(256) - 1,
                           rand(256) - 1, rand(256) - 1, rand(256) - 1,
                           rand(256) - 1, rand(256) - 1, rand(256) - 1,
                           rand(256) - 1)

        key = encode_base64(bytes)
    end

    local host_header = header_host 
                        or (is_unix and "unix_sock" or addr .. ":" .. port)

    local req = "GET " .. path .. " HTTP/1.1\r\nUpgrade: websocket\r\nHost: "
                .. host_header
                .. "\r\nSec-WebSocket-Key: " .. key
                .. (proto_header or "")
                .. "\r\nSec-WebSocket-Version: 13"
                .. (origin_header or "")
                .. "\r\nConnection: Upgrade"
                .. (custom_headers or "")
                .. "\r\n\r\n"

    local bytes, err = sock:send(req)
    if not bytes then
        return nil, "failed to send the handshake request: " .. err
    end

    local header_reader = sock:receiveuntil("\r\n\r\n")
    -- FIXME: check for too big response headers
    local header, err, partial = header_reader()
    if not header then
        return nil, "failed to receive response header: " .. err
    end

    -- error("header: " .. header)

    -- FIXME: verify the response headers

    m, err = re_match(header, [[^\s*HTTP/1\.1\s+]], "jo")
    if not m then
        return nil, "bad HTTP response status line: " .. header
    end

    return 1, nil, header
end


function _M.set_timeout(self, time)
    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    return sock:settimeout(time)
end


function _M.recv_frame(self)
    if self.fatal then
        return nil, nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    local data, typ, err =  _recv_frame(sock, self.max_recv_len, false)
    if not data and not str_find(err, ": timeout", 1, true) then
        self.fatal = true
    end
    return data, typ, err
end


local function send_frame(self, fin, opcode, payload)
    if self.fatal then
        return nil, "fatal error already happened"
    end

    if self.closed then
        return nil, "already closed"
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized yet"
    end

    local bytes, err = _send_frame(sock, fin, opcode, payload,
                                   self.max_send_len,
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


local function send_close(self, code, msg)
    local payload
    if code then
        if type(code) ~= "number" or code > 0x7fff then
            return nil, "bad status code"
        end
        payload = char(band(rshift(code, 8), 0xff), band(code, 0xff))
                        .. (msg or "")
    end

    if debug then
        ngx_log(ngx_DEBUG, "sending the close frame")
    end

    local bytes, err = send_frame(self, true, 0x8, payload)

    if not bytes then
        self.fatal = true
    end

    self.closed = true

    return bytes, err
end
_M.send_close = send_close


function _M.send_ping(self, data)
    return send_frame(self, true, 0x9, data)
end


function _M.send_pong(self, data)
    return send_frame(self, true, 0xa, data)
end


function _M.close(self)
    if self.fatal then
        return nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    if not self.closed then
        local bytes, err = send_close(self)
        if not bytes then
            return nil, "failed to send close frame: " .. err
        end
    end

    return sock:close()
end


function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end


return _M

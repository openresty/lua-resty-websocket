# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

my $pwd = cwd();
our $HttpConfig = qq{lua_package_path "$pwd/lib/?.lua;;";};

no_long_string();
run_tests();

__DATA__

=== TEST 1: unfold response fields while returning the original response
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = assert(client:new())
            local ok, err, header = wb:connect("ws://127.0.0.1:7997/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                protocols = {"chat", "superchat"}
            })
            assert(ok, err)
            local expected = "HTTP/1.1 101 Switching Protocols\r\n"
                .. "Upgrade: h2c,\r\n \twebsocket\r\n"
                .. "Connection: keep-alive,\r\n\t Upgrade\r\n"
                .. "Sec-WebSocket-Accept:\r\n s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"
                .. "Sec-WebSocket-Protocol:\r\n\t superchat"
            assert(header == expected)
            ngx.say("connected with the original response")
            assert(wb.sock:close())
        }
    }
--- tcp_listen: 7997
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: h2c,\r\n \twebsocket\r\nConnection: keep-alive,\r\n\t Upgrade\r\nSec-WebSocket-Accept:\r\n s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol:\r\n\t superchat\r\n\r\n"
--- request
GET /t
--- response_body
connected with the original response
--- no_error_log
[error]



=== TEST 2: include a folded custom request header in offered protocols
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = assert(client:new())
            local ok, err = wb:connect("ws://127.0.0.1:7997/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                headers = {"Sec-WebSocket-Protocol: chat,\r\n \tsuperchat"}
            })
            assert(ok, err)
            ngx.say("selected the protocol from the continuation line")
            assert(wb.sock:close())
        }
    }
--- tcp_listen: 7997
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: superchat\r\n\r\n"
--- request
GET /t
--- response_body
selected the protocol from the continuation line
--- no_error_log
[error]



=== TEST 3: a folded suffix cannot turn a valid prefix into a valid field
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local cases = {
                {1, "websocket\r\n garbage", "Upgrade"},
                {2, "Upgrade\r\n garbage", "Connection"},
                {3, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n garbage", "Sec-WebSocket-Accept"},
                {4, "chat\r\n garbage", "Sec-WebSocket-Protocol"},
                {3, "s3pPLMBiTxaQ9kY\r\n GzzhZRbK+xOo=", "Sec-WebSocket-Accept"},
            }

            for i, case in ipairs(cases) do
                local fields = {
                    "Upgrade: websocket",
                    "Connection: Upgrade",
                    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
                    "Sec-WebSocket-Protocol: chat",
                }
                fields[case[1]] = case[3] .. ": " .. case[2]
                local header = "HTTP/1.1 101 Switching Protocols\r\n"
                               .. table.concat(fields, "\r\n")
                local sock = {}
                function sock:connect()
                    return true
                end

                function sock:getreusedtimes()
                    return 0
                end

                function sock:send(data)
                    return #data
                end

                function sock:receiveuntil()
                    return function()
                        return header
                    end
                end

                function sock:close()
                    self.closed = true
                    return true
                end

                local wb = {sock = sock}
                local ok, err, response = client.connect(wb, "ws://127.0.0.1/", {
                    key = "dGhlIHNhbXBsZSBub25jZQ==",
                    protocols = {"chat"}
                })
                assert(ok == nil and response == header)
                assert(wb.sock == nil and sock.closed)
                ngx.say(i, ": ", err)
            end
        }
    }
--- request
GET /t
--- response_body
1: failed websocket handshake: bad Upgrade header
2: failed websocket handshake: bad Connection header
3: failed websocket handshake: bad Sec-WebSocket-Accept header
4: failed websocket handshake: bad Sec-WebSocket-Protocol header
5: failed websocket handshake: bad Sec-WebSocket-Accept header
--- no_error_log
[error]



=== TEST 4: unfolding preserves rejection of repeated singleton fields
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local cases = {
                {"Sec-WebSocket-Accept", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="},
                {"Sec-WebSocket-Protocol", "chat"},
            }

            for _, case in ipairs(cases) do
                local header = "HTTP/1.1 101 Switching Protocols\r\n"
                    .. "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                    .. "Sec-WebSocket-Accept:\r\n s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"
                    .. "Sec-WebSocket-Protocol:\r\n chat\r\n"
                    .. case[1] .. ":\r\n " .. case[2]
                local sock = {}
                function sock:connect()
                    return true
                end

                function sock:getreusedtimes()
                    return 0
                end

                function sock:send(data)
                    return #data
                end

                function sock:receiveuntil()
                    return function()
                        return header
                    end
                end

                function sock:close()
                    self.closed = true
                    return true
                end

                local wb = {sock = sock}
                local ok, err, response = client.connect(wb, "ws://127.0.0.1/", {
                    key = "dGhlIHNhbXBsZSBub25jZQ==",
                    protocols = {"chat"}
                })
                assert(ok == nil and response == header)
                assert(wb.sock == nil and sock.closed)
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Accept header
failed websocket handshake: bad Sec-WebSocket-Protocol header
--- no_error_log
[error]

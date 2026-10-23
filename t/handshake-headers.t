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

=== TEST 1: missing upgrade fields
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Upgrade header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 2: wrong upgrade
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x68\x74\x74\x70\x2f\x32\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Upgrade header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 3: connection substring is not a token
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x6e\x6f\x74\x75\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Connection header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 4: missing accept
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Accept header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 5: wrong accept
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x77\x72\x6f\x6e\x67\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Accept header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 6: duplicate accept
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Accept header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 7: unsolicited protocol
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x3a\x20\x63\x68\x61\x74\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 8: unoffered protocol
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==", protocols = {"chat", "superchat"}
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x3a\x20\x6f\x74\x68\x65\x72\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 9: multiple selected protocols
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==", protocols = {"chat", "superchat"}
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x3a\x20\x63\x68\x61\x74\x2c\x73\x75\x70\x65\x72\x63\x68\x61\x74\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 10: unsolicited extension
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x45\x78\x74\x65\x6e\x73\x69\x6f\x6e\x73\x3a\x20\x70\x65\x72\x6d\x65\x73\x73\x61\x67\x65\x2d\x64\x65\x66\x6c\x61\x74\x65\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: unexpected Sec-WebSocket-Extensions header
socket: false
pool: false, not initialized
--- no_error_log
[error]



=== TEST 11: mixed case OWS and connection tokens
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x75\x50\x67\x52\x61\x44\x65\x3a\x20\x20\x09\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x09\x20\x0d\x0a\x63\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x6b\x65\x65\x70\x2d\x61\x6c\x69\x76\x65\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x20\x09\x55\x70\x47\x72\x41\x64\x45\x20\x0d\x0a\x73\x45\x63\x2d\x57\x65\x42\x73\x4f\x63\x4b\x65\x54\x2d\x61\x43\x63\x45\x70\x54\x3a\x20\x20\x09\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x09\x20\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
connected
socket: true
--- no_error_log
[error]



=== TEST 12: one of offered protocols selected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==", protocols = {"chat", "superchat"}
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x50\x4c\x4d\x42\x69\x54\x78\x61\x51\x39\x6b\x59\x47\x7a\x7a\x68\x5a\x52\x62\x4b\x2b\x78\x4f\x6f\x3d\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x3a\x20\x73\x75\x70\x65\x72\x63\x68\x61\x74\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
connected
socket: true
--- no_error_log
[error]



=== TEST 13: accept is case sensitive
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err, header = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            assert(header and header:sub(1, 12) == "HTTP/1.1 101")
            ngx.say(ok and "connected" or err)
            ngx.say("socket: ", wb.sock ~= nil)
            if not ok then
                local pooled, err = wb:set_keepalive()
                ngx.say("pool: ", pooled or false, ", ", err)

            else
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"\x48\x54\x54\x50\x2f\x31\x2e\x31\x20\x31\x30\x31\x20\x53\x77\x69\x74\x63\x68\x69\x6e\x67\x20\x50\x72\x6f\x74\x6f\x63\x6f\x6c\x73\x0d\x0a\x55\x70\x67\x72\x61\x64\x65\x3a\x20\x77\x65\x62\x73\x6f\x63\x6b\x65\x74\x0d\x0a\x43\x6f\x6e\x6e\x65\x63\x74\x69\x6f\x6e\x3a\x20\x55\x70\x67\x72\x61\x64\x65\x0d\x0a\x53\x65\x63\x2d\x57\x65\x62\x53\x6f\x63\x6b\x65\x74\x2d\x41\x63\x63\x65\x70\x74\x3a\x20\x73\x33\x70\x70\x6c\x6d\x62\x69\x74\x78\x61\x71\x39\x6b\x79\x67\x7a\x7a\x68\x7a\x72\x62\x6b\x2b\x78\x6f\x6f\x3d\x0d\x0a\x0d\x0a"
--- request
GET /t
--- response_body
failed websocket handshake: bad Sec-WebSocket-Accept header
socket: false
pool: false, not initialized
--- no_error_log
[error]

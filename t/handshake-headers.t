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



=== TEST 14: subprotocol offered through a custom header
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                headers = {"sEc-WeBsOcKeT-pRoToCoL:\tchat , superchat\t"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: superchat\r\n\r\n"
--- request
GET /t
--- response_body
connect: 1, nil
socket: true
--- no_error_log
[error]



=== TEST 15: combine generated and repeated custom subprotocol offers
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                protocols = {"chat"},
                headers = {"Sec-WebSocket-Protocol: superchat",
                           "sec-websocket-protocol: binary"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: binary\r\n\r\n"
--- request
GET /t
--- response_body
connect: 1, nil
socket: true
--- no_error_log
[error]



=== TEST 16: custom subprotocol offers are case sensitive
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                headers = {"Sec-WebSocket-Protocol: Chat"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: chat\r\n\r\n"
--- request
GET /t
--- response_body
connect: false, failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
--- no_error_log
[error]



=== TEST 17: an empty offer member cannot match an empty selected protocol
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                protocols = "chat,"
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol:\r\n\r\n"
--- request
GET /t
--- response_body
connect: false, failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
--- no_error_log
[error]



=== TEST 18: an empty custom offer member cannot match a blank selected protocol
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                headers = {"Sec-WebSocket-Protocol: ,chat"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: \t \r\n\r\n"
--- request
GET /t
--- response_body
connect: false, failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
--- no_error_log
[error]



=== TEST 19: repeated ignored headers and upgrade token fields
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                protocols = {"chat"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: h2c\r\nConnection: keep-alive\r\n"
. ("X-Filler: abcdefghijklmnop\r\n" x 4096)
. "uPgRaDe: \tWebSocket \t\r\ncOnNeCtIoN: \tUpGrade\t \r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: chat\r\n\r\n"
--- request
GET /t
--- response_body
connect: 1, nil
socket: true
--- no_error_log
[error]



=== TEST 20: repeated selected protocol fields are rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                protocols = {"chat"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Protocol: chat\r\nsEc-WeBsOcKeT-pRoToCoL: chat\r\n\r\n"
--- request
GET /t
--- response_body
connect: false, failed websocket handshake: bad Sec-WebSocket-Protocol header
socket: false
--- no_error_log
[error]



=== TEST 21: ignored header with long interior whitespace
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ=="
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nX-Filler: a"
. (" " x 6000)
. "b\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n"
--- request
GET /t
--- response_body
connect: 1, nil
socket: true
--- no_error_log
[error]



=== TEST 22: trim header whitespace including the final field
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:7986/", {
                key = "dGhlIHNhbXBsZSBub25jZQ==",
                protocols = {"chat"}
            })
            ngx.say("connect: ", ok or false, ", ", err)
            ngx.say("socket: ", wb.sock ~= nil)
            if ok then
                wb.sock:close()
            end
        }
    }
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r\nUpgrade:\t websocket \t\r\nConnection: \tUpgrade\t \r\nX-Empty:\r\nX-Spaces: "
. (" " x 6000)
. "\r\nX-Tabs:\t\t\t\r\nSec-WebSocket-Protocol:\t chat \t\r\nSec-WebSocket-Accept:\t "
. (" " x 6000)
. "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
. ("\t " x 3000)
. "\r\n\r\n"
--- request
GET /t
--- response_body
connect: 1, nil
socket: true
--- no_error_log
[error]



=== TEST 23: interior whitespace is not a token separator
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local spaces = string.rep(" ", 6000)
            local cases = {
                {"web socket", "Upgrade", "chat", "Upgrade"},
                {"websocket", "up grade", "chat", "Connection"},
                {"websocket", "Upgrade", "chat" .. spaces .. "other",
                 "Sec-WebSocket-Protocol"},
                {"web" .. spaces .. "socket", "Upgrade", "chat", "Upgrade"},
                {"websocket", "up" .. spaces .. "grade", "chat", "Connection"},
            }

            for i, case in ipairs(cases) do
                local header = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: "
                               .. case[1] .. "\r\nConnection: " .. case[2]
                               .. "\r\nSec-WebSocket-Accept: "
                               .. "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
                               .. "\r\nSec-WebSocket-Protocol: " .. case[3]
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
                local ok, err = client.connect(wb, "ws://127.0.0.1/", {
                    key = "dGhlIHNhbXBsZSBub25jZQ==",
                    protocols = {"chat"}
                })
                ngx.say(i, ": ", ok or false, ", ", err)
                assert(wb.sock == nil and sock.closed)
            end
        }
    }
--- request
GET /t
--- response_body
1: false, failed websocket handshake: bad Upgrade header
2: false, failed websocket handshake: bad Connection header
3: false, failed websocket handshake: bad Sec-WebSocket-Protocol header
4: false, failed websocket handshake: bad Upgrade header
5: false, failed websocket handshake: bad Connection header
--- no_error_log
[error]



=== TEST 24: a bare CR or LF cannot terminate a required header value
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local cases = {
                {1, "\r", "Upgrade"},
                {1, "\n", "Upgrade"},
                {2, "\r", "Connection"},
                {2, "\n", "Connection"},
                {3, "\r", "Sec-WebSocket-Accept"},
                {3, "\n", "Sec-WebSocket-Accept"},
            }

            for i, case in ipairs(cases) do
                local fields = {
                    "Upgrade: websocket",
                    "Connection: Upgrade",
                    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
                }
                fields[case[1]] = fields[case[1]] .. case[2] .. "ignored"
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
                local ok, err = client.connect(wb, "ws://127.0.0.1/", {
                    key = "dGhlIHNhbXBsZSBub25jZQ=="
                })
                ngx.say(i, ": ", ok or false, ", ", err)
                assert(wb.sock == nil and sock.closed)
            end
        }
    }
--- request
GET /t
--- response_body
1: false, failed websocket handshake: bad Upgrade header
2: false, failed websocket handshake: bad Upgrade header
3: false, failed websocket handshake: bad Connection header
4: false, failed websocket handshake: bad Connection header
5: false, failed websocket handshake: bad Sec-WebSocket-Accept header
6: false, failed websocket handshake: bad Sec-WebSocket-Accept header
--- no_error_log
[error]

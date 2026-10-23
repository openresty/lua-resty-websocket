# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

my $pwd = cwd();
our $HttpConfig = qq{lua_package_path "$pwd/lib/?.lua;;";};
our $ServerConfig = q{
    location = /ws {
        content_by_lua_block {
            local wb = assert(require("resty.websocket.server"):new())
            local data = assert(wb:recv_frame())
            assert(wb:send_text(data))
            wb:recv_frame()
        }
    }
};

no_long_string();
run_tests();

__DATA__

=== TEST 1: select one protocol from a table offer
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local wb = assert(require("resty.websocket.client"):new())
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err, header = wb:connect(uri, {
                protocols = {"chat", "superchat"}
            })
            assert(ok, err)
            local m = assert(ngx.re.match(header,
                [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
            ngx.say("selected: ", m[1])
            assert(wb:send_text("hello"))
            local data, typ = wb:recv_frame()
            ngx.say(data, ": ", typ)
            assert(wb:close())
        }
    }
}
--- request
GET /t
--- response_body
selected: chat
hello: text
--- no_error_log
[error]



=== TEST 2: preserve a scalar protocol offer
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local wb = assert(require("resty.websocket.client"):new())
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err, header = wb:connect(uri, { protocols = "chat" })
            assert(ok, err)
            local m = assert(ngx.re.match(header,
                [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
            ngx.say("selected: ", m[1])
            assert(wb:send_text("hello"))
            local data, typ = wb:recv_frame()
            ngx.say(data, ": ", typ)
            assert(wb:close())
        }
    }
}
--- request
GET /t
--- response_body
selected: chat
hello: text
--- no_error_log
[error]



=== TEST 3: omit the selected protocol when none was offered
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local wb = assert(require("resty.websocket.client"):new())
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err, header = wb:connect(uri)
            assert(ok, err)
            local m = ngx.re.match(header,
                [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo")
            ngx.say("selected: ", m and m[1] or "none")
            assert(wb:send_text("hello"))
            local data, typ = wb:recv_frame()
            ngx.say(data, ": ", typ)
            assert(wb:close())
        }
    }
}
--- request
GET /t
--- response_body
selected: none
hello: text
--- no_error_log
[error]



=== TEST 4: trim whitespace around offered protocols
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local wb = assert(require("resty.websocket.client"):new())
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err, header = wb:connect(uri, {
                protocols = " \tchat \t, \tsuperchat \t"
            })
            assert(ok, err)
            local m = assert(ngx.re.match(header,
                [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
            ngx.say("selected: ", m[1])
            assert(wb:send_text("hello"))
            local data, typ = wb:recv_frame()
            ngx.say(data, ": ", typ)
            assert(wb:close())
        }
    }
}
--- request
GET /t
--- response_body
selected: chat
hello: text
--- no_error_log
[error]



=== TEST 5: combine repeated protocol request headers
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local wb = assert(require("resty.websocket.client"):new())
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err, header = wb:connect(uri, {
                protocols = "chat,superchat",
                headers = {"Sec-WebSocket-Protocol: xml, json"}
            })
            assert(ok, err)
            local m = assert(ngx.re.match(header,
                [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
            ngx.say("selected: ", m[1])
            assert(wb:send_text("hello"))
            local data, typ = wb:recv_frame()
            ngx.say(data, ": ", typ)
            assert(wb:close())
        }
    }
}
--- request
GET /t
--- response_body
selected: chat
hello: text
--- no_error_log
[error]



=== TEST 6: reject a malformed protocol after a valid one
--- http_config eval: $::HttpConfig
--- config
    keepalive_timeout 0;

    location = /t {
        content_by_lua_block {
            local wb, err = require("resty.websocket.server"):new()
            ngx.say(wb and "connected" or err)
        }
    }
--- request
GET /t
--- more_headers
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: chat,invalid protocol
--- response_body
bad "sec-websocket-protocol" request header
--- no_error_log
[error]



=== TEST 7: reject a malformed repeated protocol header
--- http_config eval: $::HttpConfig
--- config
    keepalive_timeout 0;

    location = /t {
        content_by_lua_block {
            local wb, err = require("resty.websocket.server"):new()
            ngx.say(wb and "connected" or err)
        }
    }
--- request
GET /t
--- more_headers
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: chat
Sec-WebSocket-Protocol: invalid protocol
--- response_body
bad "sec-websocket-protocol" request header
--- no_error_log
[error]



=== TEST 8: ignore empty members around valid protocol offers
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local offers = {
                ",chat,superchat",
                "chat,superchat,",
                "chat,,superchat",
                " \t, \t, \tchat \t, \t, \tsuperchat \t, \t, \t"
            }
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            for _, protocols in ipairs(offers) do
                local wb = assert(require("resty.websocket.client"):new())
                local ok, err, header = wb:connect(uri, {
                    protocols = protocols
                })
                assert(ok, err)
                local m = assert(ngx.re.match(header,
                    [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
                ngx.say("selected: ", m[1])
                assert(wb:send_text("hello"))
                local data, typ = wb:recv_frame()
                ngx.say(data, ": ", typ)
                assert(wb:close())
            end
        }
    }
}
--- request
GET /t
--- response_body
selected: chat
hello: text
selected: chat
hello: text
selected: chat
hello: text
selected: chat
hello: text
--- no_error_log
[error]



=== TEST 9: ignore empty members across repeated protocol headers
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local offers = {
                {
                    "Sec-WebSocket-Protocol:",
                    "Sec-WebSocket-Protocol: , \t,",
                    "Sec-WebSocket-Protocol: \tchat,\tsuperchat\t",
                    "Sec-WebSocket-Protocol:"
                },
                {
                    "Sec-WebSocket-Protocol: ,\tchat,,",
                    "Sec-WebSocket-Protocol: ",
                    "Sec-WebSocket-Protocol: ,superchat,\t,"
                }
            }
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            for _, headers in ipairs(offers) do
                local wb = assert(require("resty.websocket.client"):new())
                local ok, err, header = wb:connect(uri, { headers = headers })
                assert(ok, err)
                local m = assert(ngx.re.match(header,
                    [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
                ngx.say("selected: ", m[1])
                assert(wb:send_text("hello"))
                local data, typ = wb:recv_frame()
                ngx.say(data, ": ", typ)
                assert(wb:close())
            end
        }
    }
}
--- request
GET /t
--- response_body
selected: chat
hello: text
selected: chat
hello: text
--- no_error_log
[error]



=== TEST 10: reject a protocol list containing only empty members
--- http_config eval: $::HttpConfig
--- config
    keepalive_timeout 0;

    location = /t {
        content_by_lua_block {
            local wb, err = require("resty.websocket.server"):new()
            ngx.say(wb and "connected" or err)
        }
    }
--- request
GET /t
--- more_headers
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: , ,
--- response_body
bad "sec-websocket-protocol" request header
--- no_error_log
[error]



=== TEST 11: reject repeated protocol headers containing only empty members
--- http_config eval: $::HttpConfig
--- config
    keepalive_timeout 0;

    location = /t {
        content_by_lua_block {
            local wb, err = require("resty.websocket.server"):new()
            ngx.say(wb and "connected" or err)
        }
    }
--- request
GET /t
--- more_headers
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol:
Sec-WebSocket-Protocol: ,
Sec-WebSocket-Protocol:
--- response_body
bad "sec-websocket-protocol" request header
--- no_error_log
[error]



=== TEST 12: reject a malformed protocol among empty members
--- http_config eval: $::HttpConfig
--- config
    keepalive_timeout 0;

    location = /t {
        content_by_lua_block {
            local wb, err = require("resty.websocket.server"):new()
            ngx.say(wb and "connected" or err)
        }
    }
--- request
GET /t
--- more_headers
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: ,chat,,invalid protocol,,
--- response_body
bad "sec-websocket-protocol" request header
--- no_error_log
[error]



=== TEST 13: select from a long list without exhausting the regex JIT stack
--- http_config eval: $::HttpConfig
--- config eval
$::ServerConfig . q{
    location = /t {
        content_by_lua_block {
            local protocols = {}
            for i = 1, 1000 do
                protocols[i] = "p" .. i
            end

            local wb = assert(require("resty.websocket.client"):new())
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err, header = wb:connect(uri, { protocols = protocols })
            assert(ok, err)
            local m = assert(ngx.re.match(header,
                [[\r\nSec-WebSocket-Protocol: ([^\r\n]+)]], "ijo"))
            ngx.say("selected: ", m[1])
            assert(wb:send_text("hello"))
            local data, typ = wb:recv_frame()
            ngx.say(data, ": ", typ)
            assert(wb:close())
        }
    }
}
--- request
GET /t
--- response_body
selected: p1
hello: text
--- no_error_log
[error]



=== TEST 14: reject a malformed member at the end of a long list
--- http_config eval: $::HttpConfig
--- config
    keepalive_timeout 0;

    location = /t {
        content_by_lua_block {
            local wb, err = require("resty.websocket.server"):new()
            ngx.say(wb and "connected" or err)
        }
    }
--- request
GET /t
--- more_headers eval
"Upgrade: websocket\nConnection: Upgrade\n"
. "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\n"
. "Sec-WebSocket-Version: 13\nSec-WebSocket-Protocol: "
. CORE::join(",", map { "p$_" } 1..1000) . ",invalid protocol"
--- response_body
bad "sec-websocket-protocol" request header
--- no_error_log
[error]

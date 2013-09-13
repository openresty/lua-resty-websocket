# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);
use Protocol::WebSocket::Frame;

#repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_REDIS_PORT} ||= 6379;

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: text frame
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            ngx.say("1: received: ", data, " (", typ, ")")

            local bytes, err = wb:send_text("copy: " .. data)
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end

            data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 2nd frame: ", err)
                return
            end

            ngx.say("2: received: ", data, " (", typ, ")")
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local bytes, err = wb:send_text("你好, WebSocket!")
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            -- send it back!
            bytes, err = wb:send_text(data)
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 2nd text: ", err)
                return ngx.exit(444)
            end
        ';
    }
--- request
GET /c
--- response_body
1: received: 你好, WebSocket! (text)
2: received: copy: 你好, WebSocket! (text)
--- no_error_log
[error]
[warn]



=== TEST 2: binary frame
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            ngx.say("1: received: ", data, " (", typ, ")")

            local bytes, err = wb:send_binary("copy: " .. data)
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end

            data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 2nd frame: ", err)
                return
            end

            ngx.say("2: received: ", data, " (", typ, ")")
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local bytes, err = wb:send_binary("你好, WebSocket!")
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            -- send it back!
            bytes, err = wb:send_binary(data)
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 2nd text: ", err)
                return ngx.exit(444)
            end
        ';
    }
--- request
GET /c
--- response_body
1: received: 你好, WebSocket! (binary)
2: received: copy: 你好, WebSocket! (binary)
--- no_error_log
[error]
[warn]



=== TEST 3: close frame (without msg body)
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            -- print("c: receiving frame")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            -- print("c: received frame")

            ngx.say("received ", typ, ": ", data, ": ", err)

            local bytes, err = wb:send_close()
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            -- print("s: sending close")

            local bytes, err = wb:send_close()
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            -- print("s: sent close")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.WARN, "received: ", typ, ": ", data, ": ", err)
        ';
    }
--- request
GET /c
--- response_body
received close: : nil

--- error_log
received: close: : nil
--- no_error_log
[error]



=== TEST 4: close frame (with msg body)
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            -- print("c: receiving frame")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            -- print("c: received frame")

            ngx.say("received ", typ, ": ", data, ": ", err)

            local bytes, err = wb:send_close(1000, "server, let\'s close!")
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            -- print("s: sending close")

            local bytes, err = wb:send_close(1001, "client, let\'s close!")
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            -- print("s: sent close")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.WARN, "received: ", typ, ": ", data, ": ", err)
        ';
    }
--- request
GET /c
--- response_body
received close: client, let's close!: 1001

--- error_log
received: close: server, let's close!: 1000
--- no_error_log
[error]



=== TEST 5: ping frame (without msg body)
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            -- print("c: receiving frame")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            -- print("c: received frame")

            ngx.say("received ", typ, ": ", data, ": ", err)

            local bytes, err = wb:send_ping()
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            -- print("s: sending close")

            local bytes, err = wb:send_ping()
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            -- print("s: sent close")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.WARN, "received: ", typ, ": ", data, ": ", err)
        ';
    }
--- request
GET /c
--- response_body
received ping: : nil

--- error_log
received: ping: : nil
--- no_error_log
[error]



=== TEST 6: ping frame (with msg body)
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            -- print("c: receiving frame")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            -- print("c: received frame")

            ngx.say("received ", typ, ": ", data, ": ", err)

            local bytes, err = wb:send_ping("hey, server?")
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            -- print("s: sending close")

            local bytes, err = wb:send_ping("hey, client?")
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            -- print("s: sent close")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.WARN, "received: ", typ, ": ", data, ": ", err)
        ';
    }
--- request
GET /c
--- response_body
received ping: hey, client?: nil

--- error_log
received: ping: hey, server?: nil
--- no_error_log
[error]



=== TEST 7: pong frame (without msg body)
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            -- print("c: receiving frame")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            -- print("c: received frame")

            ngx.say("received ", typ, ": ", data, ": ", err)

            local bytes, err = wb:send_pong()
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            -- print("s: sending close")

            local bytes, err = wb:send_pong()
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            -- print("s: sent close")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.WARN, "received: ", typ, ": ", data, ": ", err)
        ';
    }
--- request
GET /c
--- response_body
received pong: : nil

--- error_log
received: pong: : nil
--- no_error_log
[error]



=== TEST 8: pong frame (with msg body)
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            -- print("c: receiving frame")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive 1st frame: ", err)
                return
            end

            -- print("c: received frame")

            ngx.say("received ", typ, ": ", data, ": ", err)

            local bytes, err = wb:send_pong("halo, server!")
            if not bytes then
                ngx.say("failed to send frame: ", err)
                return
            end
        ';
    }

    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            -- print("s: sending close")

            local bytes, err = wb:send_pong("halo, client!")
            if not bytes then
                ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
                return ngx.exit(444)
            end

            -- print("s: sent close")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed to receive a frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.WARN, "received: ", typ, ": ", data, ": ", err)
        ';
    }
--- request
GET /c
--- response_body
received pong: halo, client!: nil

--- error_log
received: pong: halo, server!: nil
--- no_error_log
[error]


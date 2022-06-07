# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);
use Protocol::WebSocket::Frame;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 7);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

check_accum_error_log();
no_long_string();

run_tests();

__DATA__

=== TEST 1: client max_send_len
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb, err = client:new({
                max_send_len = 200,
            })
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            local frame = string.rep("1", 200)

            local sent, err = wb:send_text(frame)
            if not sent then
                ngx.say("failed to send 1st frame: ", err)
                return
            end

            ngx.say("1: sent a frame of len ", #frame)

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive frame: ", err)
                return
            end

            ngx.say("2: received ", typ, " frame of len ", #data)

            frame = string.rep("1", 201)
            sent, err = wb:send_text(frame)
            if sent then
                ngx.say("expected sending 2nd frame to fail")
                return
            end

            ngx.say("3: failed sending a frame of len ", #frame, ": ", err)
        }
    }

    location = /s {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.INFO, "1: received ", typ, " frame of len ", #data)

            local sent, err = wb:send_text(data)
            if not sent then
                ngx.log(ngx.ERR, "failed sending frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "2: sent ", typ, " frame of len ", #data)
        }
    }
--- request
GET /c
--- response_body
1: sent a frame of len 200
2: received text frame of len 200
3: failed sending a frame of len 201: payload too big
--- no_error_log
[error]
[warn]
--- error_log
1: received text frame of len 200
2: sent text frame of len 200



=== TEST 2: client max_recv_len
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb, err = client:new({
                max_recv_len = 200,
            })
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            local frame = string.rep("1", 200)

            local sent, err = wb:send_text(frame)
            if not sent then
                ngx.say("failed to send 1st frame: ", err)
                return
            end

            ngx.say("1: sent a frame of len ", #frame)

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive frame: ", err)
                return
            end

            ngx.say("2: received ", typ, " frame of len ", #data)

            frame = string.rep("1", 201)
            sent, err = wb:send_text(frame)
            if not sent then
                ngx.say("failed to send 2nd frame: ", err)
                return
            end

            ngx.say("3: sent a frame of len ", #frame)

            local data, typ, err = wb:recv_frame()
            if data then
                ngx.say("expected receiving 2nd frame to fail")
                return

            elseif err ~= "exceeding max payload len" then
                ngx.say("unexpected error from recv_frame: ", err)
                return
            end

            ngx.say("4: failed receiving frame: ", err)
        }
    }

    location = /s {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "1: received ", typ, " frame of len ", #data)

            local sent, err = wb:send_text(data)
            if not sent then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "2: sent frame of len ", #data)

            data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "3: received ", typ, " frame of len ", #data)

            sent, err = wb:send_text(data)
            if not sent then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "4: sent frame of len ", #data)
        }
    }
--- request
GET /c
--- response_body
1: sent a frame of len 200
2: received text frame of len 200
3: sent a frame of len 201
4: failed receiving frame: exceeding max payload len
--- no_error_log
[error]
[warn]
--- error_log
1: received text frame of len 200
2: sent frame of len 200
3: received text frame of len 201
4: sent frame of len 201



=== TEST 3: server max_send_len
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua_block {
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
                ngx.say("failed to receive frame: ", err)
                return
            end

            ngx.say("1: received ", typ, " frame of len ", #data)

            local frame = string.rep("1", 300)
            local sent, err = wb:send_text(frame)
            if not sent then
                ngx.say("failed sending frame: ", err)
                return
            end

            ngx.say("2: sent a text frame of len ", #frame)
            --wb:recv_frame()
        }
    }

    location = /s {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new({
                max_send_len = 200,
            })
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local frame = string.rep("1", 200)
            local sent, err = wb:send_text(frame)
            if not sent then
                ngx.log(ngx.ERR, "failed sending 1st frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "1: sent frame of len ", #frame)


            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "2: received ", typ, " frame of len ", #data)

            sent, err = wb:send_text(data)
            if sent then
                ngx.log(ngx.ERR, "expected sending 2nd frame to fail")
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "3: failed sending frame of len ", #data, ": ", err)
        }
    }
--- request
GET /c
--- response_body
1: received text frame of len 200
2: sent a text frame of len 300
--- no_error_log
[error]
[warn]
--- error_log
1: sent frame of len 200
2: received text frame of len 300
3: failed sending frame of len 300: payload too big



=== TEST 4: server max_recv_len
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end

            local frame = string.rep("1", 200)
            local sent, err = wb:send_text(frame)
            if not sent then
                ngx.say("failed sending frame: ", err)
                return
            end

            ngx.say("1: sent text frame of len ", #frame)

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive frame: ", err)
                return
            end

            ngx.say("2: received ", typ, " frame of len ", #data)

            frame = string.rep("1", 300)
            sent, err = wb:send_text(frame)
            if not sent then
                ngx.say("failed sending frame: ", err)
                return
            end

            ngx.say("3: sent text frame of len ", #frame)
        }
    }

    location = /s {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new({
                max_recv_len = 200,
            })
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.log(ngx.ERR, "failed receiving frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "1: received ", typ, " frame of len ", #data)

            local sent, err = wb:send_text(data .. data)
            if not sent then
                ngx.log(ngx.ERR, "failed sending frame: ", err)
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "2: sent ", typ, " frame of len ", #data * 2)

            local data, typ, err = wb:recv_frame()
            if data then
                ngx.log(ngx.ERR, "expected recv to fail")
                return ngx.exit(444)
            end

            ngx.log(ngx.INFO, "3: failed receiving frame: ", err)
        }
    }
--- request
GET /c
--- response_body
1: sent text frame of len 200
2: received text frame of len 400
3: sent text frame of len 300
--- no_error_log
[error]
[warn]
--- error_log
1: received text frame of len 200
2: sent text frame of len 400
3: failed receiving frame: exceeding max payload len

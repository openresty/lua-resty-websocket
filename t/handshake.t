# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * 9;

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

no_long_string();

run_tests();

__DATA__

=== TEST 1: connect fails when the server refuses the upgrade with a 403
--- http_config eval: $::HttpConfig
--- config
    location = /nows {
        return 403;
    }

    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            if not wb then
                ngx.say("failed to new websocket: ", err)
                return
            end

            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/nows"
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- response_body
failed to connect: failed websocket handshake: unexpected response status: 403
--- no_error_log
[error]



=== TEST 2: connect fails when the server answers with a redirect
--- http_config eval: $::HttpConfig
--- config
    location = /nows {
        return 301 http://example.com/;
    }

    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            if not wb then
                ngx.say("failed to new websocket: ", err)
                return
            end

            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/nows"
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- response_body
failed to connect: failed websocket handshake: unexpected response status: 301
--- no_error_log
[error]



=== TEST 3: connect still succeeds against a real websocket server
--- http_config eval: $::HttpConfig
--- config
    location = /ws {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            wb:recv_frame()
        }
    }

    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            if not wb then
                ngx.say("failed to new websocket: ", err)
                return
            end

            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
            wb:send_close()
        }
    }
--- request
GET /t
--- response_body
connected
--- no_error_log
[error]

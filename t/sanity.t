# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);
use Protocol::WebSocket::Frame;

repeat_each(2);

plan tests => repeat_each() * 103;

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

=== TEST 1: simple handshake
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
Origin: http://example.com\r
\r
"
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- no_error_log
[error]
--- error_code: 101



=== TEST 2: simple text data frame (3 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => 'foo', type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
text msg received: foo,
--- no_error_log
[error]
--- error_code: 101



=== TEST 3: simple text data frame (0 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => '', type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
text msg received: ,
--- no_error_log
[error]
--- error_code: 101



=== TEST 4: simple text data frame (125 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => "a" x 124 . "b", type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log eval
"text msg received: " . ("a" x 124) . "b,",
--- no_error_log
[error]
--- error_code: 101



=== TEST 5: simple text data frame (126 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => "a" x 125 . "b", type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log eval
"text msg received: " . ("a" x 125) . "b,",
--- no_error_log
[error]
--- error_code: 101



=== TEST 6: simple text data frame (127 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => "a" x 126 . "b", type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log eval
"text msg received: " . ("a" x 126) . "b,",
--- no_error_log
[error]
--- error_code: 101



=== TEST 7: simple text data frame (65535 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            local m, err = ngx.re.match(msg, "^a{65534}b$", "jo")
            if m then
                ngx.log(ngx.WARN, typ, " msg received is expected")
            else
                ngx.log(ngx.WARN, typ, " msg received is NOT expected")
            end
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => "a" x 65534 . "b", type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
text msg received is expected,
--- no_error_log
[error]
--- error_code: 101



=== TEST 8: simple text data frame (65536 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            local m, err = ngx.re.match(msg, "^a{65535}b$", "jo")
            if m then
                ngx.log(ngx.WARN, typ, " msg received is expected")
            else
                ngx.log(ngx.WARN, typ, " msg received is NOT expected")
            end
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => "a" x 65535 . "b", type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
text msg received is expected,
--- no_error_log
[error]
--- error_code: 101



=== TEST 9: simple text data frame (1 Mbytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            local m, err = ngx.re.match(msg, "^a+b$", "jo")
            if m and #msg == 1048576 + 1 then
                ngx.log(ngx.WARN, typ, " msg received is expected")
            else
                if err then
                    ngx.log(ngx.ERR, "failed to match regex: ", err)
                    return
                end
                ngx.log(ngx.WARN, typ, " msg received is NOT expected")
            end
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(max_payload_size => 1048576 + 1, buffer => "a" x 1048576 . "b", type => 'text', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
text msg received is expected,
--- no_error_log
[error]
--- error_code: 101



=== TEST 10: simple binary data frame (3 bytes)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => 'foo', type => 'binary', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
binary msg received: foo,
--- no_error_log
[error]
--- error_code: 101



=== TEST 11: close frame (status code + non-empty msg)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg, ": ", err)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => pack("n", 1000) . 'yes, closed', type => 'close', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
close msg received: 1000: yes, closed,
--- no_error_log
[error]
--- error_code: 101



=== TEST 12: close frame (just status code)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg, ": ", err)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => pack("n", 1002), type => 'close', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
close msg received: 1002: nil,
--- no_error_log
[error]
--- error_code: 101



=== TEST 13: close frame (no payload at all)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local websocket = require "resty.websocket.server"
            local wb, err = websocket:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            local msg, typ, err = wb:recv_frame()
            if not msg and not typ then
                ngx.log(ngx.ERR, "failed to read msg: ", err)
                return ngx.exit(444)
            end
            ngx.log(ngx.WARN, typ, " msg received: ", msg, ": ", err)
        ';
    }
--- raw_request eval
"GET /t HTTP/1.1\r
Host: server.example.com\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
Sec-WebSocket-Protocol: chat\r
Sec-WebSocket-Version: 13\r
\r
" . Protocol::WebSocket::Frame->new(buffer => "", type => 'close', masked => 1)->to_bytes();
--- response_headers
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=
Sec-WebSocket-Protocol: chat
--- response_body
--- error_log
close msg received: nil: nil,
--- no_error_log
[error]
--- error_code: 101


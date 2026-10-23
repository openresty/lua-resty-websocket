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

=== TEST 1: client and server resume at every field after a partial timeout
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local protocol = require "resty.websocket.protocol"
            local client = require "resty.websocket.client"
            local server = require "resty.websocket.server"
            local payload = string.rep("a", 126)
            local cases = 0

            for _, masked in ipairs{false, true} do
                for _, encoding in ipairs{0, 126, 127} do
                    local body = encoding == 0 and "hello"
                                 or encoding == 126 and payload
                                 or string.rep("b", 65536)
                    local frames = {}
                    local output = {send = function(_, data)
                        frames[#frames + 1] = data
                        return #data
                    end}
                    protocol.send_frame(output, true, 1, body, 65536, masked)
                    local wire = table.concat(frames)

                    local header_size = encoding == 0 and 2
                                        or encoding == 126 and 4 or 10
                    local cuts = {1, 2, header_size + 1,
                                  header_size + (masked and 5 or 2), #wire - 1}
                    if encoding ~= 0 then
                        cuts[#cuts + 1] = 3
                        cuts[#cuts + 1] = header_size
                    end

                    for _, cut in ipairs(cuts) do
                        local sock = {wire = wire .. wire, pos = 1}
                        function sock:receive(n)
                            if not self.timedout and self.pos + n - 1 > cut then
                                local partial = self.wire:sub(self.pos, cut)
                                self.pos = cut + 1
                                self.timedout = true
                                return nil, "timeout", partial
                            end

                            local data = self.wire:sub(self.pos, self.pos + n - 1)
                            self.pos = self.pos + n
                            return data
                        end

                        local wb = {sock = sock, recv_state = {}, max_recv_len = 65536}
                        local recv = masked and server.recv_frame or client.recv_frame
                        local data, typ, err = recv(wb)
                        assert(data == nil and typ == nil and err:find(": timeout", 1, true))
                        assert(not wb.fatal)
                        if not masked then
                            local ok, err = client.set_keepalive(wb)
                            assert(ok == nil and err == "cannot pool a partially received frame")
                        end

                        data, typ, err = recv(wb)
                        assert(data == body and typ == "text" and err == nil)
                        assert(next(wb.recv_state) == nil)
                        data, typ, err = recv(wb)
                        assert(data == body and typ == "text" and err == nil)
                        cases = cases + 1
                    end
                end
            end

            ngx.say("resumed frames: ", cases)
        }
    }
--- request
GET /t
--- response_body
resumed frames: 38
--- no_error_log
[error]



=== TEST 2: resume a real TCP frame after a payload timeout
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()
            local ok, err = wb:connect("ws://127.0.0.1:"
                                      .. ngx.var.server_port .. "/s")
            if not ok then
                ngx.say(err)
                return
            end

            wb:set_timeout(40)
            local data, typ, err = wb:recv_frame()
            ngx.say("first: ", err, ", fatal: ", wb.fatal or false)
            wb:set_timeout(1000)
            data, typ, err = wb:recv_frame()
            ngx.say("second: ", data, ", ", typ, ", ", err)
            data, typ, err = wb:recv_frame()
            ngx.say("third: ", data, ", ", typ, ", ", err)
            wb.sock:close()
        }
    }

    location = /s {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb = server:new()
            wb.sock:send(string.char(129, 5) .. "h")
            ngx.sleep(0.2)
            wb.sock:send("ello")
            wb:send_text("done")
        }
    }
--- request
GET /c
--- response_body
first: failed to read masking-len and payload: timeout, fatal: false
second: hello, text, nil
third: done, text, nil
--- no_error_log
[crit]



=== TEST 3: server resumes a masked frame after a masking-key timeout
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new{timeout = 2000}
            local ok, err = wb:connect("ws://127.0.0.1:"
                                      .. ngx.var.server_port .. "/s")
            if not ok then
                ngx.say(err)
                return
            end

            -- Send a header and half of the four-byte zero masking key.
            wb.sock:send(string.char(129, 133, 0, 0))
            local data, typ, err = wb:recv_frame()
            assert(typ == "text" and err == nil)
            ngx.say(data)

            -- The server sends this acknowledgement only after timing out.
            -- Resume the same frame without depending on a client-side sleep.
            wb.sock:send(string.char(0, 0) .. "hello")
            data, typ, err = wb:recv_frame()
            assert(typ == "text" and err == nil)
            ngx.say(data)

            wb:send_text("next")
            data, typ, err = wb:recv_frame()
            assert(typ == "text" and err == nil)
            ngx.say(data)
            wb.sock:close()
        }
    }

    location = /s {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb = server:new{timeout = 200}
            local data, typ, err = wb:recv_frame()
            assert(data == nil and typ == nil)
            wb:send_text("first: " .. err .. ", fatal: "
                         .. tostring(wb.fatal or false))

            wb:set_timeout(2000)
            data, typ, err = wb:recv_frame()
            wb:send_text("second: " .. tostring(data) .. ", "
                         .. tostring(typ) .. ", " .. tostring(err))
            assert(next(wb.recv_state) == nil)
            data, typ, err = wb:recv_frame()
            wb:send_text("third: " .. tostring(data) .. ", "
                         .. tostring(typ) .. ", " .. tostring(err))
            assert(next(wb.recv_state) == nil)
        }
    }
--- request
GET /c
--- response_body
first: failed to read masking-len and payload: timeout, fatal: false
second: hello, text, nil
third: next, text, nil
--- no_error_log
[crit]

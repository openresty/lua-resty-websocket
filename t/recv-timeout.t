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



=== TEST 4: reconnect after a partial timeout on fresh and pooled connections
--- http_config eval: $::HttpConfig
--- config
    lua_socket_log_errors off;

    location = /c {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port

            for _, reuse in ipairs{false, true} do
                local mode = reuse and "pooled" or "fresh"
                local opts = {pool = ngx.var.request_id .. ":" .. mode}

                if reuse then
                    local spare = assert(client:new{timeout = 2000})
                    assert(spare:connect(uri .. "/echo", opts))
                    assert(spare.sock:getreusedtimes() == 0)
                    assert(spare:send_text("ready"))
                    local data, typ, err = spare:recv_frame()
                    assert(data == "ready" and typ == "text" and err == nil)
                    assert(spare:set_keepalive())
                end

                local wb = assert(client:new{timeout = 2000})
                assert(wb:connect(uri .. "/partial", {
                    pool = opts.pool .. ":partial"
                }))
                assert(wb.sock:getreusedtimes() == 0)
                wb:set_timeout(40)
                local data, typ, err = wb:recv_frame()
                assert(data == nil and typ == nil)
                assert(err == "failed to read masking-len and payload: timeout")
                assert(not wb.fatal)

                wb:set_timeout(2000)
                local ok, err, response = wb:connect(uri .. "/echo", opts)
                assert(ok == 1 and err == nil)
                assert(wb.sock:getreusedtimes() == (reuse and 1 or 0))
                if reuse then
                    assert(response == "connection reused")
                end

                assert(wb:send_text("new"))
                data, typ, err = wb:recv_frame()
                assert(data == "new" and typ == "text" and err == nil)
                assert(wb:send_text("next"))
                data, typ, err = wb:recv_frame()
                assert(data == "next" and typ == "text" and err == nil)
                assert(wb.sock:close())
                ngx.say(mode, ": new, next")
            end
        }
    }

    location = /partial {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb = assert(server:new{timeout = 2000})
            assert(wb.sock:send(string.char(129, 5) .. "h"))

            -- Wait for reconnect to close this socket instead of completing
            -- the old frame or depending on a server-side sleep.
            local data, typ, err = wb:recv_frame()
            assert(data == nil and typ == nil)
            assert(err == "failed to receive the first 2 bytes: closed")
        }
    }

    location = /echo {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb = assert(server:new{timeout = 2000})
            while true do
                local data, typ, err = wb:recv_frame()
                if not data then
                    assert(typ == nil)
                    assert(err == "failed to receive the first 2 bytes: closed")
                    return
                end

                assert(typ == "text" and err == nil)
                assert(wb:send_text(data))
            end
        }
    }
--- request
GET /c
--- response_body
fresh: new, next
pooled: new, next
--- no_error_log
[error]



=== TEST 5: repeated partial and empty timeouts preserve large frames and the next frame
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local protocol = require "resty.websocket.protocol"
            local client = require "resty.websocket.client"
            local server = require "resty.websocket.server"
            local pattern = string.rep("a\0bcdefg", 16384)
            local budgets = {1, 0, 2, 0, 1019}
            local cases = 0

            for _, masked in ipairs{false, true} do
                for _, size in ipairs{0, 126, #pattern} do
                    local body = pattern:sub(1, size)
                    local wire = assert(protocol.build_frame(true, 2, size,
                                                             body, masked))
                    wire = wire .. assert(protocol.build_frame(true, 1, 4,
                                                               "next", masked))
                    local sock = {pos = 1, calls = 0}
                    function sock:receive(n)
                        self.calls = self.calls + 1
                        assert(self.calls < 20000)
                        local step = (self.calls - 1) % #budgets + 1
                        local budget = budgets[step]
                        if budget == 0 then
                            -- Exercise both forms of an empty partial result.
                            return nil, "timeout", step == 2 and "" or nil
                        end

                        local chunk = wire:sub(self.pos,
                                               self.pos + math.min(n, budget) - 1)
                        self.pos = self.pos + #chunk
                        if #chunk < n then
                            return nil, "timeout", chunk
                        end

                        return chunk
                    end

                    local wb = {sock = sock, recv_state = {}, max_recv_len = #pattern}
                    local recv = masked and server.recv_frame or client.recv_frame
                    for _, expected in ipairs{body, "next"} do
                        local frame_start = sock.pos
                        local data, typ, err
                        repeat
                            data, typ, err = recv(wb)
                            if not data then
                                assert(typ == nil and err:find(": timeout", 1, true))
                                assert(not wb.fatal)
                                if not masked and sock.pos > frame_start then
                                    local ok, err = client.set_keepalive(wb)
                                    assert(ok == nil)
                                    assert(err == "cannot pool a partially received frame")
                                end
                            end
                        until data
                        assert(data == expected and err == nil)
                        assert(typ == (expected == body and "binary" or "text"))
                        assert(next(wb.recv_state) == nil)
                    end

                    assert(sock.pos == #wire + 1)
                    cases = cases + 1
                end
            end

            ngx.say("resumed consecutive frames: ", cases)
        }
    }
--- request
GET /t
--- response_body
resumed consecutive frames: 6
--- no_error_log
[error]



=== TEST 6: fatal errors after repeated partial timeouts discard every frame field
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local protocol = require "resty.websocket.protocol"
            local client = require "resty.websocket.client"
            local server = require "resty.websocket.server"
            local body = string.rep("abcdefgh", 16384)
            local cases = 0

            for _, masked in ipairs{false, true} do
                local wire = assert(protocol.build_frame(true, 2, #body,
                                                         body, masked))
                for _, cut in ipairs{1, 5, 8192} do
                    local sock = {pos = 1}
                    function sock:receive(n)
                        if self.pos > cut then
                            return nil, "closed", ""
                        end

                        local chunk = wire:sub(self.pos,
                                               math.min(self.pos + n - 1,
                                                        self.pos + 1023, cut))
                        self.pos = self.pos + #chunk
                        if #chunk < n then
                            return nil, "timeout", chunk
                        end

                        return chunk
                    end

                    local wb = {sock = sock, recv_state = {}, max_recv_len = #body}
                    local recv = masked and server.recv_frame or client.recv_frame
                    local data, typ, err
                    repeat
                        data, typ, err = recv(wb)
                        assert(data == nil and typ == nil)
                    until wb.fatal

                    local prefix = cut == 1 and "failed to receive the first 2 bytes"
                                   or cut == 5 and "failed to receive the 8 byte payload length"
                                   or "failed to read masking-len and payload"
                    assert(err == prefix .. ": closed")
                    assert(next(wb.recv_state) == nil)
                    data, typ, err = recv(wb)
                    assert(data == nil and typ == nil)
                    assert(err == "fatal error already happened")
                    cases = cases + 1
                end
            end

            ngx.say("discarded partial frames: ", cases)
        }
    }
--- request
GET /t
--- response_body
discarded partial frames: 6
--- no_error_log
[error]

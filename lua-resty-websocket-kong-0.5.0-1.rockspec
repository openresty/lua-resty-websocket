package = "lua-resty-websocket-kong"
version = "0.5.0-1"
source = {
  url = "git://github.com/kong/lua-resty-websocket",
  tag = "0.5.0",
}
description = {
  summary = "Kong-managed fork of lua-resty-websocket",
  detailed = [[
    lua-resty-websocket-kong is a fork of the OpenResty websocket library
    that contains additional features--many of which may or may not be
    merged into OpenResty at some point.
  ]],
  license = "2-clause BSD",
  homepage = "https://github.com/Kong/lua-resty-websocket"
}
dependencies = {}
build = {
  type = "builtin",
  modules = {
    ["resty.websocket.client"] = "lib/resty/websocket/client.lua",
    ["resty.websocket.server"] = "lib/resty/websocket/server.lua",
    ["resty.websocket.protocol"] = "lib/resty/websocket/protocol.lua",
  }
}

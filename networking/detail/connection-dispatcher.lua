local logger_data, channel, address, port = ...

-- A thread has a Lua state of its own: load love.filesystem (its module
-- searcher) and look in build/ first, as main.lua does.
require("love.filesystem")
love.filesystem.setRequirePath("build/?.lua;build/?/init.lua;?.lua;?/init.lua")

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, "connection-dispatcher")

local server, bind_err = Socket.bind(address, tonumber(port))
assert(not bind_err, bind_err)
logger:log("Connection dispatcher started working")

while true do
    logger:log("Waiting for connection...")

    local client = server:accept()
    logger:log("New client found")

    local dispatcher_channel = love.thread.newChannel()
    local in_thread = love.thread.newThread("networking/detail/server-in.lua")
    in_thread:start(logger_data, address, dispatcher_channel, channel, in_thread)

    local in_port = dispatcher_channel:demand()
    if in_port then
        local in_port_string = tostring(in_port)
        logger:log("Received receiver port " .. in_port_string)
        client:send(in_port_string .. "\n")
    else
        logger:log("Server input port not received")
        in_thread:release()
    end
    dispatcher_channel:release()

    client:close()
    logger:log("Dispatcher connection closed for client with port " .. in_port)
end

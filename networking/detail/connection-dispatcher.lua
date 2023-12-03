local logger_data, channel, address, port = ...

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, "connection-dispatcher")

local server, error = Socket.bind(address, tonumber(port))
assert(not error, error)
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
        local inPortString = tostring(in_port)
        logger:log("Received receiver port " .. inPortString)
        client:send(inPortString .. "\n")
    else
        logger:log("Server input port not received")
        in_thread:release()
    end
    dispatcher_channel:release()

    client:close()
    logger:log("Dispatcher connection closed for client with port " .. in_port)
end

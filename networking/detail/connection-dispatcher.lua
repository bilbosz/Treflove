local loggerData, channel, address, port = ...

local Socket = require("socket")
local logger = require("utils.logger")(loggerData, "connection-dispatcher")

local server, error = Socket.bind(address, tonumber(port))
assert(not error, error)
logger:log("Connection dispatcher started working")

while true do
    logger:log("Waiting for connection...")

    local client = server:accept()
    logger:log("New client found")

    local dispatcherChannel = love.thread.newChannel()
    local inThread = love.thread.newThread("networking/detail/server-in.lua")
    inThread:start(loggerData, address, dispatcherChannel, channel, inThread)

    local inPort = dispatcherChannel:demand()
    if inPort then
        local inPortString = tostring(inPort)
        logger:log("Received receiver port " .. inPortString)
        client:send(inPortString .. "\n")
    else
        logger:log("Server input port not received")
        inThread:release()
    end
    dispatcherChannel:release()

    client:close()
    logger:log("Dispatcher connection closed for client with port " .. inPort)
end

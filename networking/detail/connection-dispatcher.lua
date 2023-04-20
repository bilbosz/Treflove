local loggerData, channel, address, port = ...

local socket = require("socket")
love.filesystem.load("utils/loader.lua")()
Loader.LoadModule("utils")
Loader.LoadFile("app/consts.lua")
logger = Logger(loggerData, "connection-dispatcher")

local server, error = socket.bind(address, tonumber(port))
assert(not error, error)
logger:Log("Connection dispatcher started working")

while true do
    logger:Log("Waiting for connection...")

    local client = server:accept()
    logger:Log("New client found")

    local dispatcherChannel = love.thread.newChannel()
    local inThread = love.thread.newThread("networking/detail/server-in.lua")
    inThread:start(loggerData, address, dispatcherChannel, channel, inThread)

    local inPort = dispatcherChannel:demand()
    if inPort then
        local inPortString = tostring(inPort)
        logger:Log("Received receiver port " .. inPortString)
        client:send(inPortString .. "\n")
    else
        logger:Log("Server input port not received")
        inThread:release()
    end
    dispatcherChannel:release()

    client:close()
    logger:Log("Dispatcher connection closed for client with port " .. inPort)
end

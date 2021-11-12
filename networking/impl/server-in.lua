local loggerData, address, dispatcherChannel, channel, inThread = ...

local socket = require("socket")
love.filesystem.load("utils/loader.lua")()
Loader.LoadModule("utils")
logger = Logger(loggerData, "server-in")

local inServer, error = socket.bind(address, 0)
if error then
    logger:Log("Could not bind for receiver")
    dispatcherChannel:push(false)
    return
end

local inPort = select(2, inServer:getsockname())
logger:Log("Bound port " .. inPort .. " for receiver")
dispatcherChannel:push(inPort)

local inClient = inServer:accept()
logger:Log("Accepted client sender connection on port " .. inPort)

local outPort, error = inClient:receive("*l")
if error or not tonumber(outPort) then
    logger:Log("Could not receive client receiver port")
    dispatcherChannel:push(false)
    return
end
logger:Log("Received client receiver port " .. outPort)

local inChannel, outChannel = love.thread.newChannel(), love.thread.newChannel()
local outThread = love.thread.newThread("networking/impl/server-out.lua")
outThread:start(loggerData, address, outPort, inChannel, outChannel, channel, outThread, inThread)

while true do
    local msg, error = inClient:receive("*l")
    if error then
        if error == "closed" then
            logger:Log("Connection closed by client")
        else
            logger:Log("Error while receiving data size")
        end
        break
    end
    local n = tonumber(msg)
    if type(n) ~= "number" then
        logger:Log("Did not receive line with data size")
        break
    end
    local data, error = inClient:receive(n)
    if error then
        if error == "closed" then
            logger:Log("Connection lost")
        else
            logger:Log("Error while receiving data")
        end
        break
    end
    logger:Log("Received data with size of " .. n)
    inChannel:push(data)
end
channel:push({
    "i",
    inChannel
})

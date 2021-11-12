local loggerData, address, outPort, inChannel, outChannel, mainChannel, outThread, inThread = ...

local socket = require("socket")
love.filesystem.load("utils/loader.lua")()
Loader.LoadModule("utils")
logger = Logger(loggerData, string.format("server-out-%05i", outPort))

local outClient, error = socket.connect(address, outPort)
if error then
    logger:Log("Could not connect to client receiver on port " .. outPort)
    return
end
logger:Log("Connected to client receiver on port " .. outPort)
mainChannel:push({
    "a",
    inChannel,
    inThread,
    outChannel,
    outThread
})

local msg = outChannel:demand()
while msg ~= false do
    assert(type(msg) == "string")
    local n = #msg
    local error = select(2, outClient:send(tostring(n) .. "\n"))
    if error then
        logger:Log("Could not send data size")
        break
    end
    local error = select(2, outClient:send(msg))
    if error then
        logger:Log("Could not send data")
        break
    end
    logger:Log("Send data with size of " .. n)
    msg = outChannel:demand()
end
mainChannel:push({
    "o",
    outChannel
})

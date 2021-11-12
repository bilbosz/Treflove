local loggerData, channel, address, getPortChannel, inChannel, outChannel = ...

local socket = require("socket")
love.filesystem.load("utils/loader.lua")()
Loader.LoadModule("utils")
logger = Logger(loggerData, "client-in-?????")

local inServer, error = socket.bind(address, 0)
if error then
    logger:Log("Could not bind for receiver")
    return
end
local inPort = select(2, inServer:getsockname())
logger:SetName(string.format("client-in-%05i", inPort))
getPortChannel:push(inPort)
local inClient, error = inServer:accept()
if error then
    logger:Log("Could not connect to server")
    return
end
logger:Log("Established input connection to server. Waiting for messages...")

while true do
    local msg, error = inClient:receive("*l")
    if error then
        if error == "closed" then
            logger:Log("Connection closed by host")
        else
            logger:Log("Error when receiving data size")
        end
        break
    end
    local n = tonumber(msg)
    assert(type(n) == "number")
    local data, error = inClient:receive(n)
    if error then
        if error == "closed" then
            logger:Log("Connection lost")
        else
            logger:Log("Error when receiving data")
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

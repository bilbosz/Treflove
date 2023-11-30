local loggerData, channel, address, getPortChannel, inChannel, outChannel = ...

local Socket = require("socket")
local logger = require("utils.logger")(loggerData, "client-in-?????")

local inServer, error = Socket.bind(address, 0)
if error then
    logger:log("Could not bind for receiver")
    return
end
local inPort = select(2, inServer:getsockname())
logger:set_name(string.format("client-in-%05i", inPort))
getPortChannel:push(inPort)
local inClient, error = inServer:accept()
if error then
    logger:log("Could not connect to server")
    return
end
logger:log("Established input connection to server. Waiting for messages...")

while true do
    local msg, error = inClient:receive("*l")
    if error then
        if error == "closed" then
            logger:log("Connection closed by host")
        else
            logger:log("Error when receiving data size")
        end
        break
    end
    local n = tonumber(msg)
    assert_type(n, "number")
    local data, error = inClient:receive(n)
    if error then
        if error == "closed" then
            logger:log("Connection lost")
        else
            logger:log("Error when receiving data")
        end
        break
    end
    logger:log("Received data with size of " .. n)
    inChannel:push(data)
end
channel:push({
    "i",
    inChannel
})

local loggerData, address, outPort, inChannel, outChannel, mainChannel, outThread, inThread = ...

local Socket = require("socket")
local logger = require("utils.logger")(loggerData, string.format("server-out-%05i", outPort))

local outClient, error = Socket.connect(address, outPort)
if error then
    logger:log("Could not connect to client receiver on port " .. outPort)
    return
end
logger:log("Connected to client receiver on port " .. outPort)
mainChannel:push({
    "a",
    inChannel,
    inThread,
    outChannel,
    outThread
})

local msg = outChannel:demand()
while msg ~= false do
    assert_type(msg, "string")
    local n = #msg
    local error = select(2, outClient:send(tostring(n) .. "\n"))
    if error then
        logger:log("Could not send data size")
        break
    end
    local error = select(2, outClient:send(msg))
    if error then
        logger:log("Could not send data")
        break
    end
    logger:log("Send data with size of " .. n)
    msg = outChannel:demand()
end
mainChannel:push({
    "o",
    outChannel
})

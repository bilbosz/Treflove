local loggerData, address, dispatcherChannel, channel, inThread = ...

local Socket = require("socket")
local logger = require("utils.logger")(loggerData, "server-in-?????")

local inServer, error = Socket.bind(address, 0)
if error then
    logger:log("Could not bind for receiver")
    dispatcherChannel:push(false)
    return
end

local inPort = select(2, inServer:getsockname())
logger:set_name(string.format("server-in-%05i", inPort))
logger:log("Bound port " .. inPort .. " for receiver")
dispatcherChannel:push(inPort)

local inClient = inServer:accept()
logger:log("Accepted client sender connection on port " .. inPort)

local outPort, error = inClient:receive("*l")
if error or not tonumber(outPort) then
    logger:log("Could not receive client receiver port")
    dispatcherChannel:push(false)
    return
end
logger:log("Received client receiver port " .. outPort)

local inChannel, outChannel = love.thread.newChannel(), love.thread.newChannel()
local outThread = love.thread.newThread("networking/detail/server-out.lua")
outThread:start(loggerData, address, outPort, inChannel, outChannel, channel, outThread, inThread)

while true do
    local msg, error = inClient:receive("*l")
    if error then
        if error == "closed" then
            logger:log("Connection closed by client")
        else
            logger:log("Error while receiving data size")
        end
        break
    end
    local n = tonumber(msg)
    if type(n) ~= "number" then
        logger:log("Did not receive line with data size")
        break
    end
    local data, error = inClient:receive(n)
    if error then
        if error == "closed" then
            logger:log("Connection lost")
        else
            logger:log("Error while receiving data")
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

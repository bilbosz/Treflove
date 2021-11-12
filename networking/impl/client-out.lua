local loggerData, channel, address, port, outThread = ...

local socket = require("socket")
love.filesystem.load("utils/loader.lua")()
Loader.LoadModule("utils")
logger = Logger(loggerData, "client-out-?????")

local outPort
do
    logger:Log("Trying to connect to port " .. port)
    local client, error = socket.connect(address, tonumber(port))
    if error then
        logger:Log("Could not connect to port " .. port)
        return
    end
    outPort, error = client:receive("*l")
    logger:SetName(string.format("client-out-%05i", outPort))
    if error or not tonumber(outPort) then
        client:close()
        logger:Log("Could not receive client sender port")
        return
    end
    client:close()
    logger:Log("Dispatchee connection closed")
end

do
    local getPortChannel = love.thread.newChannel()
    local inChannel, outChannel = love.thread.newChannel(), love.thread.newChannel()
    local outClient, error = socket.connect(address, tonumber(outPort))
    if error then
        logger:Log("Could not connect to server on port " .. outPort)
        return
    end
    local inThread = love.thread.newThread("networking/impl/client-in.lua")
    inThread:start(loggerData, channel, address, getPortChannel, inChannel, outChannel)

    local inPort = getPortChannel:demand()
    local error = select(2, outClient:send(tostring(inPort) .. "\n"))
    if error then
        logger:Log("Could not send receiver port")
        return
    end
    channel:push({
        "a",
        inChannel,
        inThread,
        outChannel,
        outThread
    })
    logger:Log("Established output connection with host")

    local msg = outChannel:demand()
    while msg ~= false do
        assert(type(msg) == "string")
        local n = #msg
        local error = select(2, outClient:send(tostring(n) .. "\n"))
        if error then
            if error == "closed" then
                logger:Log("Connection closed by host")
            else
                logger:Log("Connection error when sending data size")
            end
            break
        end
        local error = select(2, outClient:send(msg))
        if error then
            if error == "closed" then
                logger:Log("Connection lost")
            else
                logger:Log("Connection error when sending data")
            end
            break
        end
        logger:Log("Send data with size of " .. n)
        msg = outChannel:demand()
    end
    channel:push({
        "o",
        outChannel
    })
end

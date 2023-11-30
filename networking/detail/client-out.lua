local loggerData, channel, address, port, outThread = ...

require("app.globals")
local Socket = require("socket")
local Logger = require("utils.logger")
local logger = Logger(loggerData, "client-out-?????")

local outPort
do
    logger:log("Trying to connect to port " .. port)
    local client, error = Socket.connect(address, tonumber(port))
    if error then
        logger:log("Could not connect to port " .. port)
        return
    end
    outPort, error = client:receive("*l")
    logger:set_name(string.format("client-out-%05i", outPort))
    if error or not tonumber(outPort) then
        client:close()
        logger:log("Could not receive client sender port")
        return
    end
    client:close()
    logger:log("Dispatchee connection closed")
end

do
    local getPortChannel = love.thread.newChannel()
    local inChannel, outChannel = love.thread.newChannel(), love.thread.newChannel()
    local outClient, error = Socket.connect(address, tonumber(outPort))
    if error then
        logger:log("Could not connect to server on port " .. outPort)
        return
    end
    local inThread = love.thread.newThread("networking/detail/client-in.lua")
    inThread:start(loggerData, channel, address, getPortChannel, inChannel, outChannel)

    local inPort = getPortChannel:demand()
    local error = select(2, outClient:send(tostring(inPort) .. "\n"))
    if error then
        logger:log("Could not send receiver port")
        return
    end
    channel:push({
        "a",
        inChannel,
        inThread,
        outChannel,
        outThread
    })
    logger:log("Established output connection with host")

    local msg = outChannel:demand()
    while msg ~= false do
        assert_type(msg, "string")
        local n = #msg
        local error = select(2, outClient:send(tostring(n) .. "\n"))
        if error then
            if error == "closed" then
                logger:log("Connection closed by host")
            else
                logger:log("Connection error when sending data size")
            end
            break
        end
        local error = select(2, outClient:send(msg))
        if error then
            if error == "closed" then
                logger:log("Connection lost")
            else
                logger:log("Connection error when sending data")
            end
            break
        end
        logger:log("Send data with size of " .. n)
        msg = outChannel:demand()
    end
    channel:push({
        "o",
        outChannel
    })
end

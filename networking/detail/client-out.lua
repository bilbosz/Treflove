local logger_data, channel, address, port, out_thread = ...

require("app.globals")
local Socket = require("socket")
local Logger = require("utils.logger")
local logger = Logger(logger_data, "client-out-?????")

local out_port
do
    logger:log("Trying to connect to port " .. port)
    local client, error = Socket.connect(address, tonumber(port))
    if error then
        logger:log("Could not connect to port " .. port)
        return
    end
    out_port, error = client:receive("*l")
    logger:set_name(string.format("client-out-%05i", out_port))
    if error or not tonumber(out_port) then
        client:close()
        logger:log("Could not receive client sender port")
        return
    end
    client:close()
    logger:log("Dispatchee connection closed")
end

do
    local getPortChannel = love.thread.newChannel()
    local in_channel, out_channel = love.thread.newChannel(), love.thread.newChannel()
    local out_client, error = Socket.connect(address, tonumber(out_port))
    if error then
        logger:log("Could not connect to server on port " .. out_port)
        return
    end
    local in_thread = love.thread.newThread("networking/detail/client-in.lua")
    in_thread:start(logger_data, channel, address, getPortChannel, in_channel, out_channel)

    local in_port = getPortChannel:demand()
    local error = select(2, out_client:send(tostring(in_port) .. "\n"))
    if error then
        logger:log("Could not send receiver port")
        return
    end
    channel:push({
        "a",
        in_channel,
        in_thread,
        out_channel,
        out_thread
    })
    logger:log("Established output connection with host")

    local msg = out_channel:demand()
    while msg ~= false do
        assert_type(msg, "string")
        local n = #msg
        local error = select(2, out_client:send(tostring(n) .. "\n"))
        if error then
            if error == "closed" then
                logger:log("Connection closed by host")
            else
                logger:log("Connection error when sending data size")
            end
            break
        end
        local error = select(2, out_client:send(msg))
        if error then
            if error == "closed" then
                logger:log("Connection lost")
            else
                logger:log("Connection error when sending data")
            end
            break
        end
        logger:log("Send data with size of " .. n)
        msg = out_channel:demand()
    end
    channel:push({
        "o",
        out_channel
    })
end

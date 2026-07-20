local logger_data, channel, address, port, out_thread = ...

require("app.globals")
local Socket = require("socket")
local Logger = require("utils.logger")
local logger = Logger(logger_data, "client-out-?????")

local out_port
do
    logger:log("Trying to connect to port " .. port)
    local client, connect_err = Socket.connect(address, tonumber(port))
    if connect_err then
        logger:log("Could not connect to port " .. port)
        return
    end
    local port_err
    out_port, port_err = client:receive("*l")
    logger:set_name(string.format("client-out-%05i", out_port))
    if port_err or not tonumber(out_port) then
        client:close()
        logger:log("Could not receive client sender port")
        return
    end
    client:close()
    logger:log("Dispatchee connection closed")
end

do
    local get_port_channel = love.thread.newChannel()
    local in_channel, out_channel = love.thread.newChannel(), love.thread.newChannel()
    local out_client, connect_err = Socket.connect(address, tonumber(out_port))
    if connect_err then
        logger:log("Could not connect to server on port " .. out_port)
        return
    end
    local in_thread = love.thread.newThread("networking/detail/client-in.lua")
    in_thread:start(logger_data, channel, address, get_port_channel, in_channel, out_channel)

    local in_port = get_port_channel:demand()
    local send_port_err = select(2, out_client:send(tostring(in_port) .. "\n"))
    if send_port_err then
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
        local size_err = select(2, out_client:send(tostring(n) .. "\n"))
        if size_err then
            if size_err == "closed" then
                logger:log("Connection closed by host")
            else
                logger:log("Connection error when sending data size")
            end
            break
        end
        local data_err = select(2, out_client:send(msg))
        if data_err then
            if data_err == "closed" then
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

local logger_data, address, dispatcher_channel, channel, in_thread = ...

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, "server-in-?????")

local in_server, bind_err = Socket.bind(address, 0)
if bind_err then
    logger:log("Could not bind for receiver")
    dispatcher_channel:push(false)
    return
end

local in_port = select(2, in_server:getsockname())
logger:set_name(string.format("server-in-%05i", in_port))
logger:log("Bound port " .. in_port .. " for receiver")
dispatcher_channel:push(in_port)

local in_client = in_server:accept()
logger:log("Accepted client sender connection on port " .. in_port)

local out_port, port_err = in_client:receive("*l")
if port_err or not tonumber(out_port) then
    logger:log("Could not receive client receiver port")
    dispatcher_channel:push(false)
    return
end
logger:log("Received client receiver port " .. out_port)

local in_channel, out_channel = love.thread.newChannel(), love.thread.newChannel()
local out_thread = love.thread.newThread("networking/detail/server-out.lua")
out_thread:start(logger_data, address, out_port, in_channel, out_channel, channel, out_thread, in_thread)

while true do
    local msg, size_err = in_client:receive("*l")
    if size_err then
        if size_err == "closed" then
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
    local data, data_err = in_client:receive(n)
    if data_err then
        if data_err == "closed" then
            logger:log("Connection lost")
        else
            logger:log("Error while receiving data")
        end
        break
    end
    logger:log("Received data with size of " .. n)
    in_channel:push(data)
end
channel:push({
    "i",
    in_channel
})

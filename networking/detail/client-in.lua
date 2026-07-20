local logger_data, channel, address, get_port_channel, in_channel = ...

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, "client-in-?????")

local in_server, bind_err = Socket.bind(address, 0)
if bind_err then
    logger:log("Could not bind for receiver")
    return
end
local in_port = select(2, in_server:getsockname())
logger:set_name(string.format("client-in-%05i", in_port))
get_port_channel:push(in_port)
local in_client, accept_err = in_server:accept()
if accept_err then
    logger:log("Could not connect to server")
    return
end
logger:log("Established input connection to server. Waiting for messages...")

while true do
    local msg, size_err = in_client:receive("*l")
    if size_err then
        if size_err == "closed" then
            logger:log("Connection closed by host")
        else
            logger:log("Error when receiving data size")
        end
        break
    end
    local n = tonumber(msg)
    assert_type(n, "number")
    local data, data_err = in_client:receive(n)
    if data_err then
        if data_err == "closed" then
            logger:log("Connection lost")
        else
            logger:log("Error when receiving data")
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

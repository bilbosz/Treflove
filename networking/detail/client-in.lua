local logger_data, channel, address, getPortChannel, in_channel = ...

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, "client-in-?????")

local in_server, error = Socket.bind(address, 0)
if error then
    logger:log("Could not bind for receiver")
    return
end
local in_port = select(2, in_server:getsockname())
logger:set_name(string.format("client-in-%05i", in_port))
getPortChannel:push(in_port)
local in_client, error = in_server:accept()
if error then
    logger:log("Could not connect to server")
    return
end
logger:log("Established input connection to server. Waiting for messages...")

while true do
    local msg, error = in_client:receive("*l")
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
    local data, error = in_client:receive(n)
    if error then
        if error == "closed" then
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

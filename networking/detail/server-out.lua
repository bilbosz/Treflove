local logger_data, address, out_port, in_channel, out_channel, main_channel, out_thread, in_thread = ...

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, string.format("server-out-%05i", out_port))

local out_client, error = Socket.connect(address, out_port)
if error then
    logger:log("Could not connect to client receiver on port " .. out_port)
    return
end
logger:log("Connected to client receiver on port " .. out_port)
main_channel:push({
    "a",
    in_channel,
    in_thread,
    out_channel,
    out_thread
})

local msg = out_channel:demand()
while msg ~= false do
    assert_type(msg, "string")
    local n = #msg
    local error = select(2, out_client:send(tostring(n) .. "\n"))
    if error then
        logger:log("Could not send data size")
        break
    end
    local error = select(2, out_client:send(msg))
    if error then
        logger:log("Could not send data")
        break
    end
    logger:log("Send data with size of " .. n)
    msg = out_channel:demand()
end
main_channel:push({
    "o",
    out_channel
})

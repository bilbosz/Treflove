---@type LoggerData, string, string, love.Channel, love.Channel, love.Channel, love.Thread, love.Thread
local logger_data, address, out_port, in_channel, out_channel, main_channel, out_thread, in_thread = ...

local Socket = require("socket")
local logger = require("utils.logger")(logger_data, string.format("server-out-%05i", out_port))

local out_client = Socket.connect(address, assert(tonumber(out_port)))
if not out_client then
    logger:log("Could not connect to client receiver on port " .. out_port)
    return
end
logger:log("Connected to client receiver on port " .. out_port)
---@type ConnectorMessage
local established = {
    "a",
    in_channel,
    in_thread,
    out_channel,
    out_thread
}
main_channel:push(established)

local msg = out_channel:demand()
while msg ~= false do
    assert_type(msg, "string")
    local n = #msg
    local size_err = select(2, out_client:send(tostring(n) .. "\n"))
    if size_err then
        logger:log("Could not send data size")
        break
    end
    local data_err = select(2, out_client:send(msg))
    if data_err then
        logger:log("Could not send data")
        break
    end
    logger:log("Send data with size of " .. n)
    msg = out_channel:demand()
end
---@type ConnectorMessage
local stopped = {
    "o",
    out_channel
}
main_channel:push(stopped)

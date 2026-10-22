---@type LoggerData, love.Channel, love.Channel, string, string
local logger_data, connector_channel, stop_channel, address, port = ...

require("love.timer")
require("app.globals")
local Consts = require("app.consts")
local Logger = require("utils.logger")
local enet = require("enet")

local logger = Logger(logger_data, "client-host")

---@return boolean
local function is_stop_requested()
    return stop_channel:pop() ~= nil
end

local host = assert(enet.host_create())
local peer = host:connect(address .. ":" .. port)
logger:log("Connecting to " .. tostring(peer))
local connect_start = love.timer.getTime()
---@type enet.event|nil
local connect_event
while not connect_event do
    connect_event = host:service(Consts.NETWORK_SERVICE_TIMEOUT_MS)
    local is_waiting = (love.timer.getTime() - connect_start) * 1000 < Consts.NETWORK_CONNECT_TIMEOUT_MS
    if not connect_event and (not is_waiting or is_stop_requested()) then
        break
    end
end
if not connect_event or connect_event.type ~= "connect" then
    logger:log("Could not connect to " .. tostring(peer))
    peer:reset()
    host:destroy()
    return
end
peer:timeout(0, 0, Consts.NETWORK_PEER_TIMEOUT_MS)
logger:log("Connected to " .. tostring(peer))

local in_channel, out_channel = love.thread.newChannel(), love.thread.newChannel()
---@type ConnectorMessage
local connected = {
    "a",
    in_channel,
    out_channel
}
connector_channel:push(connected)

local is_connected = true
---@type number|nil
local stop_time
while is_connected do
    local event = host:service(Consts.NETWORK_SERVICE_TIMEOUT_MS)
    while event do
        if event.type == "receive" then
            in_channel:push(event.data)
        elseif event.type == "disconnect" then
            logger:log("Disconnected from " .. tostring(peer))
            is_connected = false
        end
        event = host:check_events()
    end
    local outgoing = out_channel:pop() --[[@as ConnectionOutgoing|nil]]
    while outgoing ~= nil do
        if outgoing then
            peer:send(outgoing)
        else
            peer:disconnect()
        end
        outgoing = out_channel:pop()
    end
    if not stop_time and is_stop_requested() then
        stop_time = love.timer.getTime()
        peer:disconnect()
    end
    if stop_time and (love.timer.getTime() - stop_time) * 1000 >= Consts.NETWORK_DISCONNECT_TIMEOUT_MS then
        logger:log("Gave up waiting for the disconnect of " .. tostring(peer))
        is_connected = false
    end
end
host:destroy()
---@type ConnectorMessage
local disconnected = {
    "d",
    in_channel
}
connector_channel:push(disconnected)

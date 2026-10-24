---@type LoggerData, love.Channel, love.Channel, string, string
local logger_data, connector_channel, stop_channel, address, port = ...

require("love.timer")
require("app.globals")
local Consts = require("app.consts")
local Logger = require("utils.logger")
local enet = require("enet")

local logger = Logger(logger_data, "server-host")

---@class ServerHostChannels The channels of one connected peer
---@field in_channel love.Channel What the peer sent
---@field out_channel love.Channel What to send the peer, and `false` to disconnect it

local host = assert(enet.host_create(address .. ":" .. port, Consts.NETWORK_PEER_LIMIT))
logger:log("Listening on " .. host:get_socket_address())

---@type table<enet.peer, ServerHostChannels>
local peers = {}

local is_running = true
---@type number|nil
local stop_time
while is_running do
    local event = host:service(Consts.NETWORK_SERVICE_TIMEOUT_MS)
    while event do
        local peer = assert(event.peer)
        local channels = peers[peer]
        if event.type == "connect" then
            local in_channel, out_channel = love.thread.newChannel(), love.thread.newChannel()
            peers[peer] = {
                in_channel = in_channel,
                out_channel = out_channel
            }
            peer:timeout(0, 0, Consts.NETWORK_PEER_TIMEOUT_MS)
            logger:log("Connected " .. tostring(peer))
            ---@type ConnectorMessage
            local connected = {
                "a",
                in_channel,
                out_channel
            }
            connector_channel:push(connected)
        elseif event.type == "receive" and channels then
            channels.in_channel:push(event.data)
        elseif event.type == "disconnect" and channels then
            peers[peer] = nil
            logger:log("Disconnected " .. tostring(peer))
            ---@type ConnectorMessage
            local disconnected = {
                "d",
                channels.in_channel
            }
            connector_channel:push(disconnected)
        end
        event = host:check_events()
    end
    for peer, channels in pairs(peers) do
        local outgoing = channels.out_channel:pop() --[[@as ConnectionOutgoing|nil]]
        while outgoing ~= nil do
            if outgoing then
                peer:send(outgoing)
            else
                peer:disconnect()
            end
            outgoing = channels.out_channel:pop()
        end
    end
    if not stop_time and stop_channel:pop() ~= nil then
        stop_time = love.timer.getTime()
        for peer in pairs(peers) do
            peer:disconnect()
        end
    end
    if stop_time then
        if next(peers) == nil then
            is_running = false
        elseif (love.timer.getTime() - stop_time) * 1000 >= Consts.NETWORK_DISCONNECT_TIMEOUT_MS then
            logger:log("Gave up waiting for the disconnect of the peers")
            is_running = false
        end
    end
end
host:destroy()

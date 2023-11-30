local UpdateEventListener = require("events.update-event").Listener

---@class Connector: UpdateEventListener
local Connector = class("Connector", UpdateEventListener)

function Connector:init(address, port)
    self.address = address
    self.port = port
    self.channel = love.thread.newChannel()
    self.retryTime = 1
    self.thread = nil
    self.connection_manager = nil
end

function Connector:start(connection_manager)
    self.connection_manager = connection_manager
    self:try_restart_connection()

    app.update_event_manager:register_listener(self)
end

function Connector:try_restart_connection()
    local now = love.timer.getTime()
    if not self.thread or not self.thread:isRunning() and (not self.lastStart or now - self.lastStart >= self.retryTime) then
        self.lastStart = love.timer.getTime()
        if not self.thread then
            if app.is_server then
                self.thread = love.thread.newThread("networking/detail/connection-dispatcher.lua")
            else
                self.thread = love.thread.newThread("networking/detail/client-out.lua")
            end
        end
        if app.is_server then
            self.thread:start(app.logger:get_data(), self.channel, self.address, self.port)
        else
            self.thread:start(app.logger:get_data(), self.channel, self.address, self.port, self.thread)
        end
    end
end

function Connector:handle_connections()
    while true do
        local msg = self.channel:pop()
        if not msg then
            break
        end
        local action, channel1, thread1, channel2, thread2 = unpack(msg)
        if action == "a" then
            self.connection_manager:add_connection(channel1, thread1, channel2, thread2)
        elseif action == "i" then
            self.connection_manager:remove_by_in_channel(channel1)
        elseif action == "o" then
            self.connection_manager:remove_by_out_channel(channel1)
        end
    end
end

function Connector:remove_thread()
    self.thread = nil
end

function Connector:on_update()
    self:try_restart_connection()
    self:handle_connections()
end

return Connector

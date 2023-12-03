local UpdateEventListener = require("events.update-event").Listener
local NotificationPanel = require("panels.notification-panel")
local Consts = require("app.consts")

---@class NotificationManager: UpdateEventListener
local NotificationManager = class("NotificationManager", UpdateEventListener)

function NotificationManager:init()
    self.panel = NotificationPanel(self)
    self.notifications = {}
    app.update_event_manager:register_listener(self)
end

function NotificationManager:notify(message, duration)
    table.insert(self.notifications, {
        message = message,
        start_time = app:get_time(),
        duration = duration or Consts.NOTIFICATION_DURATION
    })
    self.panel:update_notifications()
end

function NotificationManager:get_notifications()
    return self.notifications
end

function NotificationManager:clear_notifications()
    self.notifications = {}
    self.panel:update_notifications()
end

function NotificationManager:on_update()
    local time = app:get_time()
    local to_remove
    for i, notification in ipairs(self.notifications) do
        if time > notification.start_time + notification.duration then
            to_remove = to_remove or {}
            table.insert(to_remove, i)
        end
    end
    if to_remove then
        for _, i in ripairs(to_remove) do
            table.remove(self.notifications, i)
        end
        self.panel:update_notifications()
    end
end

return NotificationManager

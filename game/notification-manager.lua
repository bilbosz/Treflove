local UpdateEventListener = require("events.update-event").Listener
local NotificationPanel = require("panels.notification-panel")
local Consts = require("app.consts")

---@class Notification
---@field public message string
---@field public start_time number
---@field public duration number

---@class NotificationManager: UpdateEventListener
---@field private _panel NotificationPanel
---@field private _notifications Notification[]
local NotificationManager = class("NotificationManager", UpdateEventListener)

function NotificationManager:init()
    self._panel = NotificationPanel(self)
    self._notifications = {}
    app.update_event_manager:register_listener(self)
end

---@param message string
---@param duration number
function NotificationManager:notify(message, duration)
    table.insert(self._notifications, {
        message = message,
        start_time = app:get_time(),
        duration = duration or Consts.NOTIFICATION_DURATION
    })
    self._panel:update_notifications()
end

---@private
---@return Notification[]
function NotificationManager:_get_notifications()
    return self._notifications
end

function NotificationManager:clear_notifications()
    self._notifications = {}
    self._panel:update_notifications()
end

function NotificationManager:on_update()
    local time = app:get_time()
    local to_remove
    for i, notification in ipairs(self._notifications) do
        if time > notification.start_time + notification.duration then
            to_remove = to_remove or {}
            table.insert(to_remove, i)
        end
    end
    if to_remove then
        for _, i in ripairs(to_remove) do
            table.remove(self._notifications, i)
        end
        self._panel:update_notifications()
    end
end

return NotificationManager

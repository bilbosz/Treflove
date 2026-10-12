-- game/notification-manager.lua (still Lua): timed notifications, drawn by
-- the NotificationPanel.
global record Notification
    message: string
    start_time: number -- app:get_time() when notified
    duration: number -- seconds
end

global interface NotificationManager is Object
    _panel: NotificationPanel
    _notifications: {Notification}
    notify: function(self, message: string, duration?: number) -- default Consts.NOTIFICATION_DURATION
    _get_notifications: function(self): {Notification} -- for the NotificationPanel
    clear_notifications: function(self)
    on_update: function(self) -- on app.update_event
end

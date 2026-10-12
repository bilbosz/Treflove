-- panels/notification-panel.lua (still Lua): draws the notifications of
-- app.notification_manager in the bottom right corner.
global interface NotificationPanel is Object
    _anchor: Control
    _width: number
    _height: number
    _center_anchor: function(self)
    _add_line: function(self, line: string, y: number): Text
    -- Adds the notification's lines upwards from y; returns the next y.
    _add_notification: function(self, notification: Notification, y: number): number
    _position_anchor: function(self)
    update_notifications: function(self)
    on_update: function(self) -- on app.update_event
    on_resize: function(self) -- on app.resize_manager.resized
end

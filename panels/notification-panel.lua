local UpdateEventListener = require("events.update-event").Listener
local ResizeEventListener = require("events.resize").Listener
local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Text = require("controls.text")

---@class NotificationPanel: UpdateEventListener, ResizeEventListener
---@field private _anchor Control
local NotificationPanel = class("NotificationPanel", UpdateEventListener, ResizeEventListener)

---@private
---@return void
function NotificationPanel:_center_anchor()
    self._anchor = ClippingRectangle(app.root, 0, 0)
end

---@private
---@param line string
---@param y number
---@return Text
function NotificationPanel:_add_line(line, y)
    local ctrl = Text(self._anchor, line, Consts.NOTIFICATION_COLOR)
    local ctrl_w, ctrl_h = ctrl:get_size()
    ctrl:set_scale(Consts.NOTIFICATION_TEXT_SCALE)
    ctrl:set_origin(ctrl_w, ctrl_h)
    ctrl:set_position(self.width - Consts.NOTIFICATION_PADDING, y)
    return ctrl
end

---@private
---@param notification Notification
---@param y number
---@return number
function NotificationPanel:_add_notification(notification, y)
    ---@type string[]
    local lines = {}

    for line in string.gmatch(notification.message, "[^\n]+") do
        table.insert(lines, line)
    end

    for _, line in ripairs(lines) do
        local ctrl = self:_add_line(line, y)
        local s = ctrl:get_scale()
        local _, h = ctrl:get_size()
        y = y - h * s
    end

    return y - Consts.NOTIFICATION_VSPACE
end

---@private
---@return void
function NotificationPanel:_position_anchor()
    self._anchor:set_position(app.width, app.height)
    local w, h = Consts.NOTIFICATION_PANEL_WIDTH * app.width, Consts.NOTIFICATION_PANEL_HEIGHT * app.height
    self.width, self.height = w, h
    self._anchor:set_size(w, h)
    self._anchor:set_origin(w, h)
end

---@return void
function NotificationPanel:init()
    self:_center_anchor()
    self:_position_anchor()
    app.update_event_manager:register_listener(self)
    app.resize_manager:register_listener(self)
end

---@return void
function NotificationPanel:update_notifications()
    for _, child in ipairs(self._anchor:get_children()) do
        child:set_parent(nil)
    end
    local y = self.height - Consts.NOTIFICATION_PADDING
    for _, notification in ipairs(app.notification_manager:_get_notifications()) do
        y = self:_add_notification(notification, y)
    end
end

---@return void
function NotificationPanel:on_update()
    self._anchor:reattach()
end

---@return void
function NotificationPanel:on_resize()
    self:_position_anchor()
    self:update_notifications()
end

return NotificationPanel

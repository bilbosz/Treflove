local UpdateEventListener = require("events.update-event").Listener
local ResizeEventListener = require("events.resize").Listener
local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Text = require("controls.text")

---@class NotificationPanel: UpdateEventListener, ResizeEventListener
local NotificationPanel = class("NotificationPanel", UpdateEventListener, ResizeEventListener)

local function _center_anchor(self)
    self.anchor = ClippingRectangle(app.root, 0, 0)
end

local function _add_line(self, line, y)
    local ctrl = Text(self.anchor, line, Consts.NOTIFICATION_COLOR)
    local ctrl_w, ctrl_h = ctrl:get_size()
    ctrl:set_scale(Consts.NOTIFICATION_TEXT_SCALE)
    ctrl:set_origin(ctrl_w, ctrl_h)
    ctrl:set_position(self.width - Consts.NOTIFICATION_PADDING, y)
    return ctrl
end

local function _add_notification(self, notification, y)
    local lines = {}

    for line in string.gmatch(notification.message, "[^\n]+") do
        table.insert(lines, line)
    end

    for _, line in ripairs(lines) do
        local ctrl = _add_line(self, line, y)
        local s = ctrl:get_scale()
        local _, h = ctrl:get_size()
        y = y - h * s
    end

    return y - Consts.NOTIFICATION_VSPACE
end

local function _position_anchor(self)
    self.anchor:set_position(app.width, app.height)
    local w, h = Consts.NOTIFICATION_PANEL_WIDTH * app.width, Consts.NOTIFICATION_PANEL_HEIGHT * app.height
    self.width, self.height = w, h
    self.anchor:set_size(w, h)
    self.anchor:set_origin(w, h)
end

function NotificationPanel:init()
    _center_anchor(self)
    _position_anchor(self)
    app.update_event_manager:register_listener(self)
    app.resize_manager:register_listener(self)
end

function NotificationPanel:update_notifications()
    for _, child in ipairs(self.anchor:get_children()) do
        child:set_parent(nil)
    end
    local y = self.height - Consts.NOTIFICATION_PADDING
    for _, notification in ipairs(app.notification_manager:get_notifications()) do
        y = _add_notification(self, notification, y)
    end
end

function NotificationPanel:on_update()
    self.anchor:reattach()
end

function NotificationPanel:on_resize()
    _position_anchor(self)
    self:update_notifications()
end

return NotificationPanel

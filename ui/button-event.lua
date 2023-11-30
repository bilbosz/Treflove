local EventManager = require("events.event-manager")
local Control = require("controls.control")
local Input = require("ui.input")

---@class ButtonEventListener: Control
local ButtonEventListener = class("ButtonEventListener", Control)

function ButtonEventListener:init()
    self.selected = false
    self.hovered = false
end

function ButtonEventListener:on_pointer_enter()
    self.hovered = true
end

function ButtonEventListener:on_pointer_leave()
    self.hovered = false
end

function ButtonEventListener:on_unselect()
    self.selected = false
end

function ButtonEventListener:on_select()
    self.selected = true
end

function ButtonEventListener:on_click()

end

function ButtonEventListener:is_selected()
    return self.selected
end

function ButtonEventListener:is_hovered()
    return self.hovered
end

---@class ButtonEventManager: EventManager
local ButtonEventManager = class("ButtonEventManager", EventManager)

local function _get_listener_internal(ctrl, listeners, x, y)
    if not ctrl:is_visible() or not ctrl:get_global_recursive_aabb():is_point_inside(x, y) or is_instance_of(ctrl, Input) and ctrl:is_read_only() then
        return nil
    end
    local top
    if listeners[ctrl] then
        top = ctrl
    end
    for _, child in ipairs(ctrl:get_children()) do
        top = top or _get_listener_internal(child, listeners, x, y)
    end
    return top
end

local function _get_listener(self, x, y)
    return _get_listener_internal(app.root, select(2, next(self._methods)), x, y)
end

function ButtonEventManager:init()
    EventManager.init(self, ButtonEventListener)
    self.hover = nil
    self.selection = nil
end

function ButtonEventManager:pointer_down(x, y, id)
    assert(not self.selection)
    local selection = _get_listener(self, x, y)
    if not selection then
        return
    end
    self.selection = selection
    selection:on_select()
end

function ButtonEventManager:pointer_up(x, y, id)
    local selection = self.selection
    local top = _get_listener(self, x, y)
    if selection and selection == top then
        selection:on_unselect()
        selection:on_click()
    end
    self.selection = nil
end

function ButtonEventManager:pointer_move(x, y, id)
    local top = _get_listener(self, x, y)
    local selection = self.selection
    local hover = self.hover
    if selection then
        if selection ~= top then
            selection:on_unselect()
        end
        if selection == top and selection ~= hover then
            selection:on_select()
        end
    end
    if hover ~= top then
        if hover then
            hover:on_pointer_leave()
        end
        if top then
            top:on_pointer_enter()
        end
    end
    self.hover = top
end

return {
    Listener = ButtonEventListener,
    Manager = ButtonEventManager
}

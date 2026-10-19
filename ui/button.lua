local Event = require("events.event")

---Pointer button behaviour composed into a Control (see `Input`): holds the
---hovered/selected state that `ButtonEventManager` drives and announces every
---change on its own events. The owning control registers its methods on them,
---e.g. `button.clicked:register(self, self.on_click)`; all events are triggered
---with no arguments, after the state has changed.
---
---The control makes the button reachable by pointer with
---`app.button_event_manager:register(ctrl, button)`.
---@class Button: Object
---@field public clicked Event Pointer pressed and released over the same control
---@field public selected Event Pointer pressed over the control, or dragged back onto it while pressed
---@field public unselected Event Pressed pointer dragged off the control, or released over it (before `clicked`)
---@field public pointer_entered Event Pointer moved onto the control
---@field public pointer_left Event Pointer moved off the control
---@field private _hovered boolean
---@field private _selected boolean
local Button = class("Button")

function Button:init()
    self.clicked = Event()
    self.selected = Event()
    self.unselected = Event()
    self.pointer_entered = Event()
    self.pointer_left = Event()
    self._hovered = false
    self._selected = false
end

---@return boolean
function Button:is_hovered()
    return self._hovered
end

---@return boolean
function Button:is_selected()
    return self._selected
end

function Button:enter()
    self._hovered = true
    self.pointer_entered:trigger()
end

function Button:leave()
    self._hovered = false
    self.pointer_left:trigger()
end

function Button:select()
    self._selected = true
    self.selected:trigger()
end

function Button:unselect()
    self._selected = false
    self.unselected:trigger()
end

function Button:click()
    self.clicked:trigger()
end

return Button

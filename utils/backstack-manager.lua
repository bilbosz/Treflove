local KeyboardEventListener = require("events.keyboard").Listener
local Consts = require("app.consts")

---@class BackstackManager: KeyboardEventListener
local BackstackManager = class("BackstackManager", KeyboardEventListener)

function BackstackManager:init()
    self.stack = {}
    KeyboardEventListener.init(self, true)
    app.keyboard_manager:register_listener(self)
end

function BackstackManager:push(cb)
    assert_type(cb, "function")
    table.insert(self.stack, cb)
end

function BackstackManager:pop(cb)
    assert(cb)
    if cb == self:get_top() then
        table.remove(self.stack)
    end
end

function BackstackManager:get_top()
    return self.stack[#self.stack]
end

function BackstackManager:back()
    local top = self:get_top()
    if top then
        table.remove(self.stack)
        top()
    end
end

function BackstackManager:on_key_pressed(key)
    if key == Consts.BACKSTACK_KEY then
        self:back()
    end
end

return BackstackManager

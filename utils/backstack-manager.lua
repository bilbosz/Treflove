local Consts = require("app.consts")
local KeyboardEventListener = require("events.keyboard").Listener

---@alias BackstackManagerCb fun():void

---@class BackstackManager: KeyboardEventListener
---@field private _stack BackstackManagerCb[]
local BackstackManager = class("BackstackManager", KeyboardEventListener)

function BackstackManager:init()
    self._stack = {}
    KeyboardEventListener.init(self, true)
    app.keyboard_manager:register_listener(self)
end

function BackstackManager:push(cb)
    assert_type(cb, "function")
    table.insert(self._stack, cb)
end

function BackstackManager:pop(cb)
    assert(cb)
    if cb == self:get_top() then
        table.remove(self._stack)
    end
end

function BackstackManager:get_top()
    return self._stack[#self._stack]
end

function BackstackManager:back()
    local top = self:get_top()
    if top then
        table.remove(self._stack)
        top()
    end
end

function BackstackManager:on_key_pressed(key)
    if key == Consts.BACKSTACK_KEY then
        self:back()
    end
end

return BackstackManager

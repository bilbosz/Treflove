local Consts = require("app.consts")

---@alias BackstackManagerCb fun()

---@class BackstackManager
---@field private _stack BackstackManagerCb[]
local BackstackManager = class("BackstackManager")

function BackstackManager:init()
    self._stack = {}
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
end

---@param cb BackstackManagerCb
function BackstackManager:push(cb)
    assert_type(cb, "function")
    table.insert(self._stack, cb)
end

---@param cb BackstackManagerCb
function BackstackManager:pop(cb)
    assert(cb)
    if cb == self:get_top() then
        table.remove(self._stack)
    end
end

---@return BackstackManagerCb|nil
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

---@param key love.KeyConstant
function BackstackManager:on_key_pressed(key)
    if key == Consts.BACKSTACK_KEY then
        self:back()
    end
end

return BackstackManager

local Consts = require("app.consts")
local lifetime = require("lifetime")

---@alias BackstackManagerCb fun()

---@class BackstackEntry: Object
---@field cb BackstackManagerCb
local BackstackEntry = class("BackstackEntry")

---@param cb BackstackManagerCb
function BackstackEntry:init(cb)
    self.cb = cb
end

---@class BackstackManager: Object
---@field private _stack BackstackEntry[]
local BackstackManager = class("BackstackManager")

function BackstackManager:init()
    self._stack = {}
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
end

---@param cb BackstackManagerCb
---@return BackstackEntry
function BackstackManager:push(cb)
    assert_type(cb, "function")
    local stack = self._stack
    local entry = BackstackEntry(cb)
    table.insert(stack, entry)
    lifetime.hook(function()
        table.remove(stack, assert(table.find_array_idx(stack, entry)))
    end, entry)
    return entry
end

---@return BackstackEntry|nil
function BackstackManager:get_top()
    return self._stack[#self._stack]
end

function BackstackManager:back()
    local top = self:get_top()
    if top then
        local cb = top.cb
        lifetime.destroy(top)
        cb()
    end
end

---@param key love.KeyConstant
function BackstackManager:on_key_pressed(key)
    if key == Consts.BACKSTACK_KEY then
        self:back()
    end
end

return BackstackManager

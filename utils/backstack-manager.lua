local Consts = require("app.consts")
local lifetime = require("lifetime")

---@alias BackstackManagerCb fun()

---An entry of the back stack. `push` returns it for the caller to anchor
---(lua-lifetime): an entry leaves the stack when it dies, wherever it sits,
---so a screen's or a period's entries vanish with their owner.
---@class BackstackEntry
---@field cb BackstackManagerCb

---@class BackstackManager
---@field private _stack BackstackEntry[]
local BackstackManager = class("BackstackManager")

function BackstackManager:init()
    self._stack = {}
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
end

---Push `cb`. The entry stays until `back` reaches it, or until the owner the
---caller anchors it to dies: `lifetime.attach(app.backstack_manager:push(cb), owner)`.
---@param cb BackstackManagerCb
---@return BackstackEntry
function BackstackManager:push(cb)
    assert_type(cb, "function")
    local stack = self._stack
    ---@type BackstackEntry
    local entry = {
        cb = cb
    }
    table.insert(stack, entry)
    -- lua-lifetime: runs while the entry is dying and still findable by
    -- identity (lib/lua-lifetime/docs/02-semantics.md, "Hooks").
    lifetime.hook(function()
        table.remove(stack, assert(table.find_array_idx(stack, entry)))
    end, entry)
    return entry
end

---@return BackstackEntry|nil
function BackstackManager:get_top()
    return self._stack[#self._stack]
end

---Destroys the top entry (which pops it) and runs its callback.
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

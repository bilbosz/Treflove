local Control = require("controls.control")

---@class Screen: Object
---@field public screen Control
local Screen = class("Screen")

function Screen:init()
    self.screen = Control()
end

---@param ... any
function Screen:show(...)
    assert(not self.screen:get_parent())
    self.screen:set_parent(app.root)
end

function Screen:hide()
    assert(self.screen:get_parent())
    self.screen:set_parent(nil)
end

---lua-lifetime: a screen destroyed while shown hides itself, so its controls
---leave the root and its registrations end; the screen manager forgets it
---through a hook of its own (screens/screen-manager.lua).
---@param reason lifetime.Reason
function Screen:release(reason)
    if self.screen:get_parent() then
        self:hide()
    end
end

-- luacheck: push no unused args
---@param w number
---@param h number
function Screen:on_resize(w, h)

end
-- luacheck: pop

---@return Control
function Screen:get_control()
    return self.screen
end

return Screen

local Control = require("controls.control")
local lifetime = require("lifetime")

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

---A screen takes its control tree with it, hidden first if it was shown.
---@param reason lifetime.Reason
function Screen:release(reason)
    if self.screen:get_parent() then
        self:hide()
    end
    lifetime.destroy(self.screen)
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

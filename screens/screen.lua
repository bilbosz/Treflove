local Control = require("controls.control")

---@class Screen
---@field public screen Control
local Screen = class("Screen")

function Screen:init()
    self.screen = Control()
end

---@param ... vararg
function Screen:show(...)
    assert(not self.screen:get_parent())
    self.screen:set_parent(app.root)
end

function Screen:hide()
    assert(self.screen:get_parent())
    self.screen:set_parent(nil)
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

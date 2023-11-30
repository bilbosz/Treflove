local Control = require("controls.control")

---@class Screen
local Screen = class("Screen")

function Screen:init()
    self.screen = Control()
end

function Screen:show(...)
    assert(not self.screen:get_parent())
    self.screen:set_parent(app.root)
end

function Screen:hide()
    assert(self.screen:get_parent())
    self.screen:set_parent(nil)
end

function Screen:on_resize(w, h)

end

function Screen:get_control()
    return self.screen
end

return Screen

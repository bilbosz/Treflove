---@class MenuEntry
---@field public control nil|Control
local MenuEntry = class("MenuEntry")

function MenuEntry:init()
    self.control = nil
end

---@param parent Control
---@return Control
function MenuEntry:create_control(parent)
    return abstract()
end

---@return nil|Control
function MenuEntry:get_control()
    return self.control
end

return MenuEntry

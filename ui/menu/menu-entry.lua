---@class MenuEntry
---@field public control nil|Control
local MenuEntry = class("MenuEntry")

---@return void
function MenuEntry:init()
    self.control = nil
end

---@field parent Control
---@return Control
function MenuEntry:create_control(parent)
    abstract()
end

---@return nil|Control
function MenuEntry:get_control()
    return self.control
end

return MenuEntry

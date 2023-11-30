---@class MenuEntry
local MenuEntry = class("MenuEntry")

function MenuEntry:init()
    self.control = nil
end

function MenuEntry:create_control(parent)
    abstract()
end

function MenuEntry:get_control()
    return self.control
end

return MenuEntry

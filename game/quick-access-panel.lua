local Panel = require("ui.panel")
local Consts = require("app.consts")
local TextButton = require("ui.text-button")

---@class QuickAccessPanel: Panel
local QuickAccessPanel = class("QuickAccessPanel", Panel)

function QuickAccessPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self.game_screen = game_screen
    self.entries = {}
end

function QuickAccessPanel:AddEntry(label, entry)
    local children = self:get_children()
    local x = 0
    if #children > 1 then
        local last_child = children[#children]
        x = last_child:get_position() + last_child:get_outer_size()
    end
    x = x + Consts.PADDING
    local button = TextButton(self, self.game_screen, label, function()
        self.game_screen:select_panel(entry)
    end)
    self.entries[entry] = button

    button:set_position(x, Consts.PADDING)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
end

return QuickAccessPanel

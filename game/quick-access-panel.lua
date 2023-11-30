local Panel = require("ui.panel")
local Consts = require("app.consts")
local TextButton = require("ui.text-button")

---@class QuickAccessPanel: Panel
local QuickAccessPanel = class("QuickAccessPanel", Panel)

function QuickAccessPanel:init(gameScreen, width, height)
    Panel.init(self, gameScreen:get_control(), width, height)
    self.gameScreen = gameScreen
    self.entries = {}
end

function QuickAccessPanel:AddEntry(label, entry)
    local children = self:get_children()
    local x = 0
    if #children > 1 then
        local lastChild = children[#children]
        x = lastChild:get_position() + lastChild:get_outer_size()
    end
    x = x + Consts.PADDING
    local button = TextButton(self, self.gameScreen, label, function()
        self.gameScreen:select_panel(entry)
    end)
    self.entries[entry] = button

    button:set_position(x, Consts.PADDING)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
end

return QuickAccessPanel

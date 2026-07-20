local Panel = require("ui.panel")
local Consts = require("app.consts")
local TextButton = require("ui.text-button")

---@class QuickAccessPanel: Panel
---@field _game_screen GameScreen
---@field _entries table<Panel, TextButton> Panel-selecting buttons indexed by their target panel
local QuickAccessPanel = class("QuickAccessPanel", Panel)

---@param game_screen GameScreen
---@param width number
---@param height number
function QuickAccessPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self._game_screen = game_screen
    self._entries = {}
end

---@param label string Button caption
---@param entry Panel Panel shown when the button is pressed
function QuickAccessPanel:add_entry(label, entry)
    ---@type Control[]
    local children = self:get_children()
    local x = 0
    if #children > 1 then
        local last_child = children[#children]
        x = last_child:get_position() + last_child:get_outer_size()
    end
    x = x + Consts.PADDING
    local button = TextButton(self, self._game_screen, label, function()
        self._game_screen:select_panel(entry)
    end)
    self._entries[entry] = button

    button:set_position(x, Consts.PADDING)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
end

return QuickAccessPanel

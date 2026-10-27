local Panel = require("ui.panel")
local Consts = require("app.consts")
local TextButton = require("ui.text-button")

---@class QuickAccessPanel: Panel
---@field private _game_screen GameScreen
---@field private _buttons table<string, TextButton> By caption
local QuickAccessPanel = class("QuickAccessPanel", Panel)

---@param game_screen GameScreen
---@param width number
---@param height number
function QuickAccessPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self._game_screen = game_screen
    self._buttons = {}
end

---@param label string Button caption
---@param action InputHandler Run when the button is pressed
---@return TextButton
function QuickAccessPanel:add_entry(label, action)
    local children = self:get_children()
    local x = 0
    if #children > 1 then
        local last_child = children[#children]
        x = last_child:get_position() + last_child:get_outer_size()
    end
    x = x + Consts.PADDING
    local button = TextButton(self, self._game_screen, label, action)
    self._buttons[label] = button

    button:set_position(x, Consts.PADDING)
    button:set_scale(Consts.PANEL_FIELD_SCALE)
    return button
end

return QuickAccessPanel

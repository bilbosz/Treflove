local Panel = require("ui.panel")

---@class SidePanel: Panel
---@field protected _game_screen GameScreen
local SidePanel = class("SidePanel", Panel)

---@param game_screen GameScreen
---@param width number
---@param height number
function SidePanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self._game_screen = game_screen
end

---@return GameScreen
function SidePanel:get_game_screen()
    return self._game_screen
end

---@param kind EntryKind
---@param id string The entry's id after the change: the new one of a rename, the deleted one of a deletion
function SidePanel:on_entries_change(kind, id)
end

function SidePanel:on_grants_change()
end

function SidePanel:on_selection_change()
end

return SidePanel

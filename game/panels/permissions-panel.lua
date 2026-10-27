local EntriesPanel = require("game.panels.entries-panel")

---@class PermissionsPanel: EntriesPanel
local PermissionsPanel = class("PermissionsPanel", EntriesPanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function PermissionsPanel:init(game_screen, width, height)
    EntriesPanel.init(self, game_screen, width, height, "players")
end

return PermissionsPanel

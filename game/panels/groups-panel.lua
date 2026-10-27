local EntriesPanel = require("game.panels.entries-panel")

---@class GroupsPanel: EntriesPanel
local GroupsPanel = class("GroupsPanel", EntriesPanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function GroupsPanel:init(game_screen, width, height)
    EntriesPanel.init(self, game_screen, width, height, "groups")
end

return GroupsPanel

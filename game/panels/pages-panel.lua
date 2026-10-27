local EntriesPanel = require("game.panels.entries-panel")

---@class PagesPanel: EntriesPanel
local PagesPanel = class("PagesPanel", EntriesPanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function PagesPanel:init(game_screen, width, height)
    EntriesPanel.init(self, game_screen, width, height, "pages")
end

return PagesPanel

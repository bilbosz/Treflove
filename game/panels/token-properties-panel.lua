local EntriesPanel = require("game.panels.entries-panel")

---@class TokenPropertiesPanel: EntriesPanel
local TokenPropertiesPanel = class("TokenPropertiesPanel", EntriesPanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function TokenPropertiesPanel:init(game_screen, width, height)
    EntriesPanel.init(self, game_screen, width, height, "token_properties")
end

return TokenPropertiesPanel

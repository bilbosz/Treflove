local MenuScreen = require("screens.menu-screen")
local MenuText = require("ui.menu.menu-text")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class DeleteGameScreen: MenuScreen
---@field private _session Session
local DeleteGameScreen = class("DeleteGameScreen", MenuScreen)

---@param session Session
---@param games GameInfo[] The games the user may delete, in the order the buttons list them
function DeleteGameScreen:init(session, games)
    assert(session)
    self._session = session
    ---@type MenuEntry[]
    local entries = {}
    if #games == 0 then
        table.insert(entries, MenuText(self, "No games to delete"))
    end
    for _, info in ipairs(games) do
        table.insert(entries, MenuTextButton(self, info.name, function()
            self:pick(info.id, info.name)
        end))
    end
    table.insert(entries, MenuTextButton(self, "Back", function()
        app.backstack_manager:back()
    end))
    MenuScreen.init(self, "Delete Game", entries)
end

---@param id string
---@param name string
function DeleteGameScreen:pick(id, name)
    self._session:confirm_delete_game(id, name)
end

return DeleteGameScreen

local MenuScreen = require("screens.menu-screen")
local MenuText = require("ui.menu.menu-text")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class GamesScreen: MenuScreen
---@field private _session Session
local GamesScreen = class("GamesScreen", MenuScreen)

---@param session Session
---@param games GameInfo[] In the order the buttons list them
function GamesScreen:init(session, games)
    assert(session)
    self._session = session
    ---@type MenuEntry[]
    local entries = {}
    if #games == 0 then
        table.insert(entries, MenuText(self, "No games yet"))
    end
    for _, info in ipairs(games) do
        table.insert(entries, MenuTextButton(self, info.name, function()
            self:join_game(info.id)
        end))
    end
    table.insert(entries, MenuTextButton(self, "New Game", function()
        self:new_game()
    end))
    table.insert(entries, MenuTextButton(self, "Back", function()
        app.backstack_manager:back()
    end))
    MenuScreen.init(self, "Games", entries)
end

---@param id string
function GamesScreen:join_game(id)
    self._session:join_game(id)
end

function GamesScreen:new_game()
    self._session:show_new_game()
end

return GamesScreen

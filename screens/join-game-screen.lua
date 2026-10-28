local MenuScreen = require("screens.menu-screen")
local MenuText = require("ui.menu.menu-text")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class JoinGameScreen: MenuScreen
---@field private _session Session
local JoinGameScreen = class("JoinGameScreen", MenuScreen)

---@param session Session
---@param games GameInfo[] In the order the buttons list them
function JoinGameScreen:init(session, games)
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
    table.insert(entries, MenuTextButton(self, "Back", function()
        app.backstack_manager:back()
    end))
    MenuScreen.init(self, "Join Game", entries)
end

---@param id string
function JoinGameScreen:join_game(id)
    self._session:join_game(id)
end

return JoinGameScreen

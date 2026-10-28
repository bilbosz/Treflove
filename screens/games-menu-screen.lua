local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class GamesMenuScreen: MenuScreen
---@field private _session Session
local GamesMenuScreen = class("GamesMenuScreen", MenuScreen)

---@param session Session
function GamesMenuScreen:init(session)
    assert(session)
    self._session = session
    MenuScreen.init(self, "Games", {
        MenuTextButton(self, "New Game", function()
            self:new_game()
        end),
        MenuTextButton(self, "Join Game", function()
            self:join_game()
        end),
        MenuTextButton(self, "Delete Game", function()
            self:delete_game()
        end),
        MenuTextButton(self, "Back", function()
            app.backstack_manager:back()
        end)
    })
end

function GamesMenuScreen:new_game()
    self._session:show_new_game()
end

function GamesMenuScreen:join_game()
    self._session:show_join_game()
end

function GamesMenuScreen:delete_game()
    self._session:show_delete_game()
end

return GamesMenuScreen

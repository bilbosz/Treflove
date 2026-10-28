local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class ManageGamesScreen: MenuScreen
---@field private _session Session
local ManageGamesScreen = class("ManageGamesScreen", MenuScreen)

---@param session Session
function ManageGamesScreen:init(session)
    assert(session)
    self._session = session
    MenuScreen.init(self, "Manage Games", {
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

function ManageGamesScreen:new_game()
    self._session:show_new_game()
end

function ManageGamesScreen:join_game()
    self._session:show_games()
end

function ManageGamesScreen:delete_game()
    self._session:show_delete_game()
end

return ManageGamesScreen

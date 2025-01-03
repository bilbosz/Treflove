local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")
local OptionsMenuScreen = require("screens.options-menu-screen")

---@class UserMenuScreen: MenuScreen
---@field private _session Session
local UserMenuScreen = class("UserMenuScreen", MenuScreen)

---@param session Session
function UserMenuScreen:init(session)
    assert(session)
    self._session = session
    MenuScreen.init(self, "Menu", {
        MenuTextButton(self, "Join Game", function()
            self:join_game()
        end),
        MenuTextButton(self, "Options", function()
            self:options()
        end),
        MenuTextButton(self, "Log Out", function()
            self:logout()
        end),
        MenuTextButton(self, "Quit", function()
            self:quit()
        end)
    })
end

function UserMenuScreen:join_game()
    self._session:join_game()
end

function UserMenuScreen:options()
    app.backstack_manager:push(function()
        app.screen_manager:show(self, self._session)
    end)
    app.screen_manager:show(OptionsMenuScreen())
end

function UserMenuScreen:logout()
    self._session:logout()
end

function UserMenuScreen:quit()
    app:quit()
end

return UserMenuScreen

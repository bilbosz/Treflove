local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")
local OptionsMenuScreen = require("screens.options-menu-screen")

---@class UserMenuScreen: MenuScreen
---@field private _session Session
---@field private _options_screen OptionsMenuScreen|nil Made on the first visit, kept for the next ones
local UserMenuScreen = class("UserMenuScreen", MenuScreen)

---@param session Session
function UserMenuScreen:init(session)
    assert(session)
    self._session = session
    self._options_screen = nil
    MenuScreen.init(self, "Menu", {
        MenuTextButton(self, "Games", function()
            self:games()
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

function UserMenuScreen:games()
    self._session:show_games()
end

function UserMenuScreen:options()
    if not self._options_screen then
        self._options_screen = OptionsMenuScreen():attach_lifetime(self)
    end
    app.backstack_manager:push(function()
        app.screen_manager:show(self)
    end):attach_lifetime(self)
    app.screen_manager:show(self._options_screen)
end

function UserMenuScreen:logout()
    self._session:logout()
end

function UserMenuScreen:quit()
    app:quit()
end

return UserMenuScreen

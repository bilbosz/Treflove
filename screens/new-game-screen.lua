local Games = require("data.games")
local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")
local MenuTextInput = require("ui.menu.menu-text-input")

---@class NewGameScreen: MenuScreen
---@field private _session Session
---@field private _name_input MenuTextInput
local NewGameScreen = class("NewGameScreen", MenuScreen)

---@param session Session
function NewGameScreen:init(session)
    assert(session)
    self._session = session
    self._name_input = MenuTextInput(self, "Name", false, function()
        self:create()
    end)
    MenuScreen.init(self, "New Game", {
        self._name_input,
        MenuTextButton(self, "Create", function()
            self:create()
        end),
        MenuTextButton(self, "Back", function()
            app.backstack_manager:back()
        end)
    })
end

function NewGameScreen:create()
    local name = self._name_input:get_text()
    if not Games.make_id(name) then
        app.notification_manager:notify("A game needs a name with a letter or a digit")
        return
    end
    self._session:create_game(name)
end

return NewGameScreen

local Games = require("data.games")
local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")
local MenuTextInput = require("ui.menu.menu-text-input")

---@class DeleteGameScreen: MenuScreen
---@field private _session Session
---@field private _name_input MenuTextInput
local DeleteGameScreen = class("DeleteGameScreen", MenuScreen)

---@param session Session
function DeleteGameScreen:init(session)
    assert(session)
    self._session = session
    self._name_input = MenuTextInput(self, "Name", false, function()
        self:delete()
    end)
    MenuScreen.init(self, "Delete Game", {
        self._name_input,
        MenuTextButton(self, "Delete", function()
            self:delete()
        end),
        MenuTextButton(self, "Back", function()
            app.backstack_manager:back()
        end)
    })
end

function DeleteGameScreen:delete()
    local id = Games.make_id(self._name_input:get_text())
    if not id then
        app.notification_manager:notify("Type the name of the game to delete")
        return
    end
    self._session:delete_game(id)
end

return DeleteGameScreen

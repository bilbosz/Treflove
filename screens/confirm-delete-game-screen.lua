local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class ConfirmDeleteGameScreen: MenuScreen
---@field private _session Session
---@field private _id string
local ConfirmDeleteGameScreen = class("ConfirmDeleteGameScreen", MenuScreen)

---@param session Session
---@param id string The game's id
---@param name string The game's name, asked about in the title
function ConfirmDeleteGameScreen:init(session, id, name)
    assert(session)
    self._session = session
    self._id = id
    MenuScreen.init(self, string.format("Are you sure to delete %q game?", name), {
        MenuTextButton(self, "Yes", function()
            self:confirm()
        end),
        MenuTextButton(self, "No", function()
            app.backstack_manager:back()
        end)
    })
end

function ConfirmDeleteGameScreen:confirm()
    self._session:delete_game(self._id)
end

return ConfirmDeleteGameScreen

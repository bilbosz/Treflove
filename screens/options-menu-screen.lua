local MenuScreen = require("screens.menu-screen")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class OptionsMenuScreen: MenuScreen
local OptionsMenuScreen = class("OptionsMenuScreen", MenuScreen)

function OptionsMenuScreen:init()
    MenuScreen.init(self, "Options", {
        MenuTextButton(self, "Toggle Fullscreen", function()
            app.options_manager:toggle_fullscreen()
        end),
        MenuTextButton(self, "Back", function()
            app.backstack_manager:back()
        end)
    })
end

return OptionsMenuScreen

OptionsMenuScreen = {}

function OptionsMenuScreen:Init()
    MenuScreen.Init(self, "Options", {
        MenuTextButton(self, "Toggle Fullscreen", function()
            app.optionsManager:ToggleFullscreen()
        end),
        MenuTextButton(self, "Back", function()
            app.backstackManager:Back()
        end)
    })
end

MakeClassOf(OptionsMenuScreen, MenuScreen)

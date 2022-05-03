OptionsMenuScreen = {}

function OptionsMenuScreen:Init()
    MenuScreen.Init(self, "Options", {
        MenuTextButton("Toggle Fullscreen", function()
            app.optionsManager:ToggleFullscreen()
        end),
        MenuTextButton("Back", function()
            app.backstackManager:Back()
        end)
    })
end

MakeClassOf(OptionsMenuScreen, MenuScreen)

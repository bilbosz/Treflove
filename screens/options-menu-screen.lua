OptionsMenuScreen = {}

function OptionsMenuScreen:Init()
    MenuScreen.Init(self, "Options", {
        MenuTextButton("Toggle Fullscreen", function()
            app.optionsManager:ToggleFullscreen()
        end),
        MenuTextButton("Back", function()
            app.screenManager:Pop()
        end)
    })
end

MakeClassOf(OptionsMenuScreen, MenuScreen)

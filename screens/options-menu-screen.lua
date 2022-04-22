OptionsMenuScreen = {}

function OptionsMenuScreen:Init(session)
    MenuScreen.Init(self, "Options", {
        MenuTextButton("Toggle Fullscreen", function()
            app.optionsManager:ToggleFullscreen()
        end),
        MenuTextButton("Back", function()
            app.screenManager:Show(UserMenuScreen(session))
        end)
    })
end

MakeClassOf(OptionsMenuScreen, MenuScreen)

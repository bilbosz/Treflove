UserMenuScreen = {}

local function OnJoinGame(self)
    self.session:JoinGame()
end

local function OnOptions(self)
    app.screenManager:Show(OptionsMenuScreen(self.session))
end

local function OnLogout(self)
    self.session:Logout()
end

local function OnQuit()
    app:Quit()
end

function UserMenuScreen:Init(session)
    self.session = session
    MenuScreen.Init(self, "Menu", {
        MenuTextButton("Join Game", function()
            OnJoinGame(self)
        end),
        MenuTextButton("Options", function()
            OnOptions(self)
        end),
        MenuTextButton("Log Out", function()
            OnLogout(self)
        end),
        MenuTextButton("Quit", OnQuit)
    })
end

MakeClassOf(UserMenuScreen, MenuScreen)

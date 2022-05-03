UserMenuScreen = {}

local function OnJoinGame(self)
    self.session:JoinGame()
end

local function OnOptions(self)
    app.backstackManager:Push(function()
        app.screenManager:Show(self, self.session)
    end)
    app.screenManager:Show(OptionsMenuScreen())
end

local function OnLogout(self)
    self.session:Logout()
end

local function OnQuit()
    app:Quit()
end

function UserMenuScreen:Init(session)
    assert(session)
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

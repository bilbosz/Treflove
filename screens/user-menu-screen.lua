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
        MenuTextButton(self, "Join Game", function()
            OnJoinGame(self)
        end),
        MenuTextButton(self, "Options", function()
            OnOptions(self)
        end),
        MenuTextButton(self, "Log Out", function()
            OnLogout(self)
        end),
        MenuTextButton(self, "Quit", OnQuit)
    })
end

MakeClassOf(UserMenuScreen, MenuScreen)

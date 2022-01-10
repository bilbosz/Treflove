UserMenuScreen = {}

local function OnJoinGame(self)
    app.logger:Log("Join game clicked")
end

local function OnOptions(self)
    app.logger:Log("Options clicked")
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
        MenuButton("Join Game", function()
            OnJoinGame(self)
        end),
        MenuButton("Options", function()
            OnOptions(self)
        end),
        MenuButton("Log Out", function()
            OnLogout(self)
        end),
        MenuButton("Quit", function()
            OnQuit()
        end)
    })
end

MakeClassOf(UserMenuScreen, MenuScreen)

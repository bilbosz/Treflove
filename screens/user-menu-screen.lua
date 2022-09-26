UserMenuScreen = {}

function UserMenuScreen:Init(session)
    assert(session)
    self.session = session
    MenuScreen.Init(self, "Menu", {
        MenuTextButton(self, "Join Game", function()
            self:JoinGame()
        end),
        MenuTextButton(self, "Options", function()
            self:Options()
        end),
        MenuTextButton(self, "Log Out", function()
            self:Logout()
        end),
        MenuTextButton(self, "Quit", function()
            self:Quit()
        end)
    })
end

function UserMenuScreen:JoinGame()
    self.session:JoinGame()
end

function UserMenuScreen:Options()
    app.backstackManager:Push(function()
        app.screenManager:Show(self, self.session)
    end)
    app.screenManager:Show(OptionsMenuScreen())
end

function UserMenuScreen:Logout()
    self.session:Logout()
end

function UserMenuScreen:Quit()
    app:Quit()
end

MakeClassOf(UserMenuScreen, MenuScreen)

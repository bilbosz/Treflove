Session = {}

local function OnLogin(self, user)
    assert(not self.user)
    self.user = user
    if app.isClient then
        app.textEventManager:SetTextInput(false)
        self.userMenuScreen = UserMenuScreen(self)
        app.screenManager:Show(self.userMenuScreen)
        self.backstackCb = function()
            self:Logout()
        end
        app.backstackManager:Push(self.backstackCb)
    end
end

local function OnLogout(self)
    assert(self.user)
    self.user = nil
    if app.isClient then
        app.backstackManager:Pop(self.backstackCb)
        self.backstackCb = nil
        self.userMenuScreen = nil
        app.screenManager:Show(LoginScreen(self.login))
    end
end

function Session:Init(connection)
    self.connection = connection
    self.user = nil
    local login = Login(self, function(user)
        OnLogin(self, user)
        if app.isClient then
            self.userMenuScreen:JoinGame()
        end
    end, function()
        OnLogout(self)
    end)
    self.login = login
    self.gameDataRp = GameDataRp(self.connection)
    app.assetManager:RegisterSession(self)

    if app.isClient then
        login:Login("adam", "krause")
    end
end

function Session:GetUser()
    return self.user
end

function Session:GetConnection()
    return self.connection
end

function Session:Login(user, password)
    self.login:Login(user, password)
end

function Session:Logout()
    self.login:Logout()
end

function Session:IsLoggedIn()
    return not not self.user
end

function Session:JoinGame()
    assert(app.isClient)
    app.screenManager:Show(WaitingScreen("Loading..."))
    self.gameDataRp:SendRequest({})
end

function Session:Release()
    app.assetManager:UnregisterSession(self)
    if app.isClient then
        app.backstackManager:Pop(self.backstackCb)
        self.backstackCb = nil
    end
    self.login:Release()
    self.login = nil
    self.connection = nil
end

MakeClassOf(Session)

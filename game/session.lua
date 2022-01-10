Session = {}

local function OnLogin(self, user)
    assert(not self.user)
    self.user = user
    if app.isClient then
        app.screenManager:Push(UserMenuScreen(self))
    end
end

local function OnLogout(self)
    assert(self.user)
    self.user = nil
    if app.isClient then
        self.login:ShowLoginScreen()
    end
end

function Session:Init(connection)
    self.connection = connection
    self.user = nil
    local login = Login(self, function(user)
        OnLogin(self, user)
    end, function()
        OnLogout(self)
    end)
    self.login = login

    if app.isClient then
        login:ShowLoginScreen()
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

function Session:Release()
    self.login:Release()
    self.login = nil
    self.connection = nil
end

MakeClassOf(Session)

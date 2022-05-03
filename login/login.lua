Login = {}

local function GetClientAuth(userName, password)
    return Hash(userName .. string.char(0) .. GenerateSalt(32) .. string.char(0) .. password)
end

function Login:Init(session, onLogin, onLogout)
    self.session = session
    self.connection = session:GetConnection()
    self.onLogout = onLogout
    self.loginRp = LoginRp(self.connection, onLogin)
    self.logoutRp = LogoutRp(self.connection, onLogout)
end

function Login:Login(user, password)
    assert(app.isClient)
    self.loginRp:SendRequest({
        auth = GetClientAuth(user, password)
    })
end

function Login:Logout()
    assert(app.isClient)
    self.logoutRp:SendRequest({})
end

function Login:Release()
    self.loginRp:Release()
    self.logoutRp:Release()
end

MakeClassOf(Login)

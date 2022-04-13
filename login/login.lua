Login = {}

local function GetClientAuth(userName, password)
    return Hash(userName .. string.char(0) .. GenerateSalt(32) .. string.char(0) .. password)
end

local function PopToConnectionScreen()
    while true do
        local top = app.screenManager:Top()
        if not top then
            break
        end
        local mt = getmetatable(top)
        if mt.class == ConnectionScreen then
            break
        end
        app.screenManager:Pop()
    end
end

function Login:Init(session, onLogin, onLogout)
    self.session = session
    self.connection = session:GetConnection()
    self.onLogout = onLogout
    self.loginRp = LoginRp(self.connection, onLogin)
    self.logoutRp = LogoutRp(self.connection, onLogout)
end

function Login:ShowLoginScreen()
    assert(app.isClient)
    PopToConnectionScreen()
    app.screenManager:Push(LoginScreen(self))
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

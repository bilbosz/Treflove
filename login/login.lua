Login = {}

local function GetClientAuth(userName, password)
    return Hash(userName .. string.char(0) .. GenerateSalt(32) .. string.char(0) .. password)
end

local function GetServerAuth(userName, clientAuth)
    return Hash(userName .. string.char(0) .. GenerateSalt(32) .. string.char(0) .. clientAuth)
end

local function FindUserByClientAuth(clientAuth)
    for userName, userData in pairs(app.data.players) do
        local serverAuth = GetServerAuth(userName, clientAuth)
        if serverAuth == userData.auth then
            return userName
        end
    end
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
    self.onLogin = onLogin
    self.onLogout = onLogout
    if app.isServer then
        self.connection:RegisterRequestHandler("login", function(request)
            local user = FindUserByClientAuth(request.auth)
            if user then
                onLogin(user)
            end
            return {
                user = user
            }
        end)
        self.connection:RegisterRequestHandler("logout", function()
            onLogout()
            return {}
        end)
    end
end

function Login:ShowLoginScreen()
    assert(app.isClient)
    PopToConnectionScreen()
    app.screenManager:Push(LoginScreen(self))
end

function Login:Login(user, password)
    assert(app.isClient)
    local auth = GetClientAuth(user, password)
    self.session:GetConnection():SendRequest("login", {
        auth = auth
    }, function(response)
        if response.user then
            app.notificationManager:Notify(string.format("Successfully logged in as %s", response.user), 3)
            self.onLogin(response.user)
        else
            app.notificationManager:Notify("Wrong login or password")
        end
    end)
end

function Login:Logout()
    assert(app.isClient)
    self.session:GetConnection():SendRequest("logout", {}, function()
        self.onLogout()
    end)
end

function Login:Release()
    self.connection:UnregisterRequestHandler("login")
    self.connection:UnregisterRequestHandler("logout")
end

MakeClassOf(Login)

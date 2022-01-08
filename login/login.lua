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

function Login:Init(session, onSuccess)
    self.session = session
    self.connection = session:GetConnection()
    self.onSuccess = onSuccess
    if app.isClient then
        local screen = LoginScreen(self)
        self.screen = screen
        app.screenManager:Push(screen)
    else
        self.connection:RegisterRequestHandler("login", function(request)
            local user = FindUserByClientAuth(request.auth)
            if user then
                onSuccess(user)
            end
            return {
                user = user
            }
        end)
    end
end

function Login:LogIn(user, password)
    assert(app.isClient)
    local auth = GetClientAuth(user, password)
    self.session:GetConnection():SendRequest("login", {
        auth = auth
    }, function(response)
        if response.user then
            self.onSuccess(response.user)
        else
            self.screen:OnFail()
        end
    end)
end

function Login:Release()
    self.connection:UnregisterRequestHandler("login")
end

MakeClassOf(Login)

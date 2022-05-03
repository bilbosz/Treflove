LoginRp = {}

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

function LoginRp:Init(connection, onLogin)
    RemoteProcedure.Init(self, connection)
    self.onLogin = onLogin
end

function LoginRp:SendResponse(request)
    assert(app.isServer)
    local user = FindUserByClientAuth(request.auth)
    if user then
        self.onLogin(user)
    end
    return {
        user = user
    }
end

function LoginRp:ReceiveResponse(response)
    assert(app.isClient)
    if response.user then
        app.notificationManager:Notify(string.format("Successfully logged in as %s", response.user), 3)
        self.onLogin(response.user)
    else
        app.notificationManager:Notify("Wrong login or password")
    end
end

MakeClassOf(LoginRp, RemoteProcedure)

LogoutRp = {}

function LogoutRp:Init(connection, onLogout)
    RemoteProcedure.Init(self, connection)
    self.onLogout = onLogout
end

function LogoutRp:SendResponse()
    assert(app.isServer)
    self.onLogout()
    return {}
end

function LogoutRp:ReceiveResponse()
    assert(app.isClient)
    self.onLogout()
end

MakeClassOf(LogoutRp, RemoteProcedure)

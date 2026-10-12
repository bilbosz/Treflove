-- login/login-rp.tlt: authenticates a user on the server (constructor:
-- `LoginRp(connection: Connection, on_login: LoginOnLogin)`). Anchored to
-- its Login.

-- A player of the persisted state (GameState.players).
global record PlayerData
    name: string
    auth: string -- the server-side hash of the login and password
    group: string -- "master" or "player"
end

global record LoginRequest is RequestBody
    auth: string -- the client-side hash of the login and password
end

global record LoginResponse is ResponseBody
    user: string -- nil when no player matched
end

global interface LoginRp is RemoteProcedure
    on_login: LoginOnLogin
    send_request: function(self, request: LoginRequest, cb?: function(response: LoginResponse))
    send_response: function(self, request: LoginRequest): LoginResponse
    receive_response: function(self, response: LoginResponse)
end

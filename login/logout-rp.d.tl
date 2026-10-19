-- login/logout-rp.tlt: logs the user out on both sides (constructor:
-- `LogoutRp(connection: Connection, on_logout: LoginOnLogout)`). Anchored
-- to its Login.
global interface LogoutRp is RemoteProcedure
    on_logout: LoginOnLogout
    send_request: function(self, request: EmptyBody, cb?: function(response: EmptyBody))
    send_response: function(self, request: EmptyBody): EmptyBody
    receive_response: function(self, response: EmptyBody)
end

-- login/login.tlt: the login and logout procedures of a session
-- (constructor: `Login(session: Session, on_login: LoginOnLogin,
-- on_logout: LoginOnLogout)`). Anchored to its session (`Login(...) @
-- self`); its procedures are anchored to it (`LoginRp(...) @ self`) and die
-- in the same cascade, so it has no `release` (docs/lifetime.md).
global type LoginOnLogin = function(user: string)
global type LoginOnLogout = function()

global interface Login is Object
    _connection: Connection
    _login_rp: LoginRp
    _logout_rp: LogoutRp
    login: function(self, user: string, password: string)
    logout: function(self)
end

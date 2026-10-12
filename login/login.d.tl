-- login/login.lua (still Lua): the login and logout procedures of a
-- session. lifetime: anchored to its session (`Login(...) @ self`); its
-- procedures are anchored to it (`LoginRp(...) @ self`), so its `release`
-- needs not release them (docs/lifetime.md).
global type LoginOnLogin = function(user: string)
global type LoginOnLogout = function()

global interface Login is Object
    _connection: Connection
    _login_rp: LoginRp
    _logout_rp: LogoutRp
    login: function(self, user: string, password: string)
    logout: function(self)
end

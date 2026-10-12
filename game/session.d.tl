-- game/session.tlt: a connection's user state, login and screens
-- (constructor: `Session(connection: Connection)`). Anchored to its
-- connection (`Session(connection) @ connection`); its Login, GameDataRp,
-- asset procedures, the client's logged-in period and the login screen
-- are anchored to it, so it has no `release` (docs/lifetime.md,
-- "Ownership").
global interface Session is Object
    _user: string -- the logged-in user, nil when logged out
    _connection: Connection
    _login: Login -- anchored to the session
    _game_data_rp: GameDataRp -- anchored to the session
    _user_menu_screen: UserMenuScreen -- client, while logged in; anchored to _period
    -- The client's logged-in span, `lifetime.token("period") @ self`; the
    -- user menu screen and the back entry that logs out are anchored to it,
    -- and logging out destroys it. nil while logged out.
    _period: lifetime.Token
    get_user: function(self): string
    get_connection: function(self): Connection
    login: function(self, user: string, password: string)
    logout: function(self)
    is_logged_in: function(self): boolean
    join_game: function(self)
end

-- game/session.lua (still Lua): a connection's user state, login and
-- screens. lifetime: a session is anchored to its connection
-- (`Session(connection) @ connection`); its Login and GameDataRp are
-- anchored to it, and its `release` goes away (docs/lifetime.md).
global interface Session is Object
    _user: string -- the logged-in user, nil when logged out
    _connection: Connection
    _login: Login
    _game_data_rp: GameDataRp
    _user_menu_screen: UserMenuScreen -- client, while logged in
    -- lifetime: the client's logged-in span, `lifetime.token("period") @
    -- self`; the user menu screen and the back entry are anchored to it and
    -- logging out destroys it.
    _period: lifetime.Token
    -- lifetime: Phase 0 keeps the back entry here to destroy it; anchored
    -- to _period it needs no field and this goes away.
    _backstack_entry: BackstackEntry
    get_user: function(self): string
    get_connection: function(self): Connection
    login: function(self, user: string, password: string)
    logout: function(self)
    is_logged_in: function(self): boolean
    join_game: function(self)
end

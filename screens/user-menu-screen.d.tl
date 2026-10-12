-- screens/user-menu-screen.lua (still Lua): the menu after logging in.
-- lifetime: on the client it is anchored to the session's logged-in period
-- (Session._period) and dies when the user logs out.
global interface UserMenuScreen is MenuScreen
    _session: Session
    join_game: function(self)
    options: function(self)
    logout: function(self)
    quit: function(self)
end

-- screens/user-menu-screen.tlt: the menu after logging in.
-- lifetime: the one the session makes at login is anchored to its logged-in
-- period (Session._period) and dies when the user logs out; the one a game
-- screen's back entry shows is held by the screen manager alone.
global interface UserMenuScreen is MenuScreen
    _session: Session
    join_game: function(self)
    options: function(self)
    logout: function(self)
    quit: function(self)
end

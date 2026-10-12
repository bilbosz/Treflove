-- screens/user-menu-screen.tlt: the menu after logging in.
-- lifetime: every one is made by Session:show_user_menu (at login, and
-- from a game screen's back entry) and anchored to the session's
-- logged-in period (Session._period): it dies on logout or with the
-- session, and the back entry its Options pushes dies with it.
global interface UserMenuScreen is MenuScreen
    _session: Session
    join_game: function(self)
    options: function(self)
    logout: function(self)
    quit: function(self)
end

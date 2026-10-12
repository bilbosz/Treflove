-- login/login-screen.lua (still Lua). lifetime: anchored to the session
-- that shows it (`LoginScreen(self._login) @ self`).
global interface LoginScreen is MenuScreen
    _login: Login
    _login_input: MenuTextInput
    _password_input: MenuTextInput
end

-- login/login-screen.tlt: the login form (constructor: `LoginScreen(login:
-- Login)`). Anchored to the session that shows it (`LoginScreen(self._login)
-- @ self`).
global interface LoginScreen is MenuScreen
    _login: Login
    _login_input: MenuTextInput
    _password_input: MenuTextInput
end

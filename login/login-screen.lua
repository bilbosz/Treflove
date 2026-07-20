local MenuScreen = require("screens.menu-screen")
local MenuTextInput = require("ui.menu.menu-text-input")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class LoginScreen: MenuScreen
---@field _login Login
---@field _login_input MenuTextInput
---@field _password_input MenuTextInput
local LoginScreen = class("LoginScreen", MenuScreen)

---@param self LoginScreen
local function _submit(self)
    self._login:login(self._login_input:get_text(), self._password_input:get_text())
end

---@param login Login
function LoginScreen:init(login)
    self._login = login
    self._login_input = MenuTextInput(self, "Login", false, function()
        _submit(self)
    end)
    self._password_input = MenuTextInput(self, "Password", true, function()
        _submit(self)
    end)
    MenuScreen.init(self, "Welcome", {
        self._login_input,
        self._password_input,
        MenuTextButton(self, "Sign In", function()
            _submit(self)
        end),
        MenuTextButton(self, "Quit", function()
            app:quit()
        end)
    })
end

return LoginScreen

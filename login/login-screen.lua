local MenuScreen = require("screens.menu-screen")
local MenuTextInput = require("ui.menu.menu-text-input")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class LoginScreen: MenuScreen
local LoginScreen = class("LoginScreen", MenuScreen)

local function _login(self)
    self.login:login(self.login_input:get_text(), self.password_input:get_text())
end

function LoginScreen:init(login)
    self.login = login
    self.login_input = MenuTextInput(self, "Login", false, function()
        _login(self)
    end)
    self.password_input = MenuTextInput(self, "Password", true, function()
        _login(self)
    end)
    MenuScreen.init(self, "Welcome", {
        self.login_input,
        self.password_input,
        MenuTextButton(self, "Sign In", function()
            _login(self)
        end),
        MenuTextButton(self, "Quit", function()
            app:quit()
        end)
    })
end

return LoginScreen

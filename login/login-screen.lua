local MenuScreen = require("screens.menu-screen")
local MenuTextInput = require("ui.menu.menu-text-input")
local MenuTextButton = require("ui.menu.menu-text-button")

---@class LoginScreen: MenuScreen
local LoginScreen = class("LoginScreen", MenuScreen)

local function login(self)
    self.login:login(self.loginInput:get_text(), self.passwordInput:get_text())
end

function LoginScreen:init(login)
    self.login = login
    self.loginInput = MenuTextInput(self, "Login", false, function()
        login(self)
    end)
    self.passwordInput = MenuTextInput(self, "Password", true, function()
        login(self)
    end)
    MenuScreen.init(self, "Welcome", {
        self.loginInput,
        self.passwordInput,
        MenuTextButton(self, "Sign In", function()
            login(self)
        end),
        MenuTextButton(self, "quit", function()
            app:quit()
        end)
    })
end

return LoginScreen

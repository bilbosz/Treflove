LoginScreen = {}

local function Login(self)
    self.login:Login(self.loginInput:GetText(), self.passwordInput:GetText())
end

function LoginScreen:Init(login)
    self.login = login
    self.loginInput = MenuTextInput("Login", false, function()
        Login(self)
    end)
    self.passwordInput = MenuTextInput("Password", true, function()
        Login(self)
    end)
    MenuScreen.Init(self, "Welcome", {
        self.loginInput,
        self.passwordInput,
        MenuTextButton("Sign In", function()
            Login(self)
        end),
        MenuTextButton("Quit", function()
            app:Quit()
        end)
    })
end

MakeClassOf(LoginScreen, MenuScreen)

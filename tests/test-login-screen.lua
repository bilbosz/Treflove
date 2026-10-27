local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local LoginScreen = require("login.login-screen")
local Login = require("login.login")
local Session = require("game.session")

---@class TestLoginAttempt
---@field user string
---@field password string

---@class TestLoginScreenLogin: Login
---@field attempts TestLoginAttempt[]
local TestLoginScreenLogin = class("TestLoginScreenLogin", Login)

function TestLoginScreenLogin:init()
    self.attempts = {}
end

---@param user string
---@param password string
function TestLoginScreenLogin:login(user, password)
    table.insert(self.attempts, {
        user = user,
        password = password
    })
end

---@class TestLoginScreenSession: Session
---@field sign_up_shows integer
local TestLoginScreenSession = class("TestLoginScreenSession", Session)

function TestLoginScreenSession:init()
    self.sign_up_shows = 0
end

function TestLoginScreenSession:show_sign_up()
    self.sign_up_shows = self.sign_up_shows + 1
end

---@class TestLoginScreenSide
---@field login TestLoginScreenLogin
---@field session TestLoginScreenSession
---@field screen LoginScreen

---@param fn fun(side: TestLoginScreenSide)
local function with_screen(fn)
    local app_mock = menu_client.install()
    local session = TestLoginScreenSession()
    app_mock.session = session
    local login = TestLoginScreenLogin()
    local screen = LoginScreen(login)
    menu_client.with_screen(screen, function()
        fn({
            login = login,
            session = session,
            screen = screen
        })
    end)
end

---@param side TestLoginScreenSide
---@param caption string
local function click(side, caption)
    menu_client.click(menu_client.button(side.screen, caption))
end

test.suite("LoginScreen")

test.case("Sign Up stands between Sign In and Quit", function()
    with_screen(function(side)
        test.assert_deep_eq(menu_client.captions(side.screen), {
            "Sign In",
            "Sign Up",
            "Quit"
        })
    end)
end)

test.case("Sign Up shows the session's sign-up screen and logs nobody in", function()
    with_screen(function(side)
        click(side, "Sign Up")
        test.assert_eq(side.session.sign_up_shows, 1)
        test.assert_deep_eq(side.login.attempts, {})
    end)
end)

test.case("Sign In logs in with the fields' texts", function()
    with_screen(function(side)
        local fields = menu_client.find_all(side.screen, "TextInput") --[[@as TextInput[] ]]
        fields[1]:set_text("adam")
        fields[2]:set_text("krause")
        click(side, "Sign In")
        test.assert_deep_eq(side.login.attempts, {
            {
                user = "adam",
                password = "krause"
            }
        })
        test.assert_eq(side.session.sign_up_shows, 0)
    end)
end)

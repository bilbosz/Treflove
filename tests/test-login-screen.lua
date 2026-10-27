local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local LoginScreen = require("login.login-screen")
local Input = require("ui.input")

---@class TestLoginAttempt
---@field user string
---@field password string

---@class TestLoginScreenLogin: Login
---@field attempts TestLoginAttempt[]
local TestLoginScreenLogin = class("TestLoginScreenLogin")

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
local TestLoginScreenSession = class("TestLoginScreenSession")

function TestLoginScreenSession:init()
    self.sign_up_shows = 0
end

function TestLoginScreenSession:show_sign_up()
    self.sign_up_shows = self.sign_up_shows + 1
end

---@class TestLoginScreenSide
---@field app AppMock
---@field login TestLoginScreenLogin
---@field session TestLoginScreenSession
---@field screen LoginScreen

---@return TestLoginScreenSide
local function show_screen()
    mocks.ensure_love_graphics()
    mocks.ensure_love_math()
    local app_mock = mocks.install_app()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500
    local session = TestLoginScreenSession()
    app_mock.session = session
    local login = TestLoginScreenLogin()
    local screen = LoginScreen(login)
    screen:show()
    return {
        app = app_mock,
        login = login,
        session = session,
        screen = screen
    }
end

---@param side TestLoginScreenSide
---@param fn fun(side: TestLoginScreenSide)
local function with_screen(side, fn)
    ---@type boolean, any
    local ok, err = pcall(fn, side)
    lifetime.destroy(side.screen)
    if not ok then
        error(err, 0)
    end
end

---@param ctrl Control
---@param class_name string
---@param found Control[] The controls of `class_name` in draw order, none inside an input
local function collect(ctrl, class_name, found)
    if get_class_name_of(ctrl) == class_name then
        table.insert(found, ctrl)
    end
    if is_instance_of(ctrl, Input) then
        return
    end
    for _, child in ipairs(ctrl:get_children()) do
        collect(child, class_name, found)
    end
end

---@param side TestLoginScreenSide
---@return TextInput[] In draw order: the login, the password
local function inputs(side)
    local found = {}
    collect(side.screen:get_control(), "TextInput", found)
    return found --[[@as TextInput[] ]]
end

---@param side TestLoginScreenSide
---@return TextButton[] In draw order
local function buttons(side)
    local found = {}
    collect(side.screen:get_control(), "TextButton", found)
    return found --[[@as TextButton[] ]]
end

---@param side TestLoginScreenSide
---@param caption string
local function click_button(side, caption)
    for _, button in ipairs(buttons(side)) do
        if button:get_text() == caption then
            local min_x, min_y, max_x, max_y = button:get_global_aabb():get_bounds()
            local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
            local manager = side.app.button_event_manager
            manager:dispatch_pointer_move(x, y, 1)
            manager:dispatch_pointer_down(x, y, 1)
            manager:dispatch_pointer_up(x, y, 1)
            return
        end
    end
    error("no button " .. caption)
end

test.suite("LoginScreen")

test.case("Sign Up stands between Sign In and Quit", function()
    with_screen(show_screen(), function(side)
        local captions = {}
        for _, button in ipairs(buttons(side)) do
            table.insert(captions, button:get_text())
        end
        test.assert_deep_eq(captions, {
            "Sign In",
            "Sign Up",
            "Quit"
        })
    end)
end)

test.case("Sign Up shows the session's sign-up screen and logs nobody in", function()
    with_screen(show_screen(), function(side)
        click_button(side, "Sign Up")
        test.assert_eq(side.session.sign_up_shows, 1)
        test.assert_deep_eq(side.login.attempts, {})
    end)
end)

test.case("Sign In logs in with the fields' texts", function()
    with_screen(show_screen(), function(side)
        local fields = inputs(side)
        fields[1]:set_text("adam")
        fields[2]:set_text("krause")
        click_button(side, "Sign In")
        test.assert_deep_eq(side.login.attempts, {
            {
                user = "adam",
                password = "krause"
            }
        })
        test.assert_eq(side.session.sign_up_shows, 0)
    end)
end)

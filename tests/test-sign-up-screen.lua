local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local Accounts = require("data.accounts")
local SignUpScreen = require("login.sign-up-screen")
local Session = require("game.session")

---@class TestSignUpRequest
---@field login string
---@field name string
---@field password string

---@class TestSignUpSession: Session
---@field sign_ups TestSignUpRequest[]
local TestSignUpSession = class("TestSignUpSession", Session)

function TestSignUpSession:init()
    self.sign_ups = {}
end

---@param login string
---@param name string
---@param password string
function TestSignUpSession:sign_up(login, name, password)
    table.insert(self.sign_ups, {
        login = login,
        name = name,
        password = password
    })
end

---@class TestSignUpSide
---@field app AppMock
---@field session TestSignUpSession
---@field notifications TestNotificationManager
---@field screen SignUpScreen

---@param fn fun(side: TestSignUpSide)
local function with_screen(fn)
    local app_mock = menu_client.install()
    local session = TestSignUpSession()
    local screen = SignUpScreen(session)
    menu_client.with_screen(screen, function()
        fn({
            app = app_mock,
            session = session,
            notifications = app_mock.notification_manager --[[@as TestNotificationManager]] ,
            screen = screen
        })
    end)
end

---@param side TestSignUpSide
---@return TextInput[] In draw order: the login, the name, the password, the repeat
local function inputs(side)
    return menu_client.find_all(side.screen, "TextInput") --[[@as TextInput[] ]]
end

---@param side TestSignUpSide
---@param caption string
local function click(side, caption)
    menu_client.click(menu_client.button(side.screen, caption))
end

---@param side TestSignUpSide
---@param login string
---@param name string
---@param password string
---@param repeated string
local function fill(side, login, name, password, repeated)
    local fields = inputs(side)
    fields[1]:set_text(login)
    fields[2]:set_text(name)
    fields[3]:set_text(password)
    fields[4]:set_text(repeated)
end

test.suite("SignUpScreen")

test.case("the title, the four fields with their captions, the two password fields masked, then the buttons", function()
    with_screen(function(side)
        test.assert_deep_eq(menu_client.texts(side.screen), {
            "Sign Up",
            "Login",
            "Name",
            "Password",
            "Repeat"
        })
        test.assert_deep_eq(menu_client.captions(side.screen), {
            "Create Account",
            "Back"
        })
        local fields = inputs(side)
        test.assert_eq(#fields, 4)
        ---@type boolean[]
        local masked = {}
        for i, field in ipairs(fields) do
            ---@diagnostic disable-next-line: invisible
            masked[i] = field._masked
        end
        test.assert_deep_eq(masked, {
            false,
            false,
            true,
            true
        })
    end)
end)

test.case("Create Account asks the session for the account with the fields' texts", function()
    with_screen(function(side)
        fill(side, "frodo", "Frodo", "ring", "ring")
        click(side, "Create Account")
        test.assert_deep_eq(side.session.sign_ups, {
            {
                login = "frodo",
                name = "Frodo",
                password = "ring"
            }
        })
        test.assert_deep_eq(side.notifications.messages, {})
    end)
end)

test.case("Enter in a field submits as Create Account does", function()
    with_screen(function(side)
        fill(side, "frodo", "Frodo", "ring", "ring")
        local repeat_field = inputs(side)[4]
        menu_client.click(repeat_field)
        test.assert_true(repeat_field:is_focused())
        side.app.text_event_manager:key_pressed("return")
        test.assert_eq(#side.session.sign_ups, 1)
        test.assert_eq(side.session.sign_ups[1].login, "frodo")
    end)
end)

test.case("a refusal is notified with its reason and asks the session nothing", function()
    ---@type {[1]: string, [2]: string, [3]: string, [4]: string, [5]: string}[] The fields, then the reason
    local refusals = {
        {
            "",
            "Frodo",
            "ring",
            "ring",
            assert(Accounts.check_login(""))
        },
        {
            "frodo baggins",
            "Frodo",
            "ring",
            "ring",
            assert(Accounts.check_login("frodo baggins"))
        },
        {
            "@frodo",
            "Frodo",
            "ring",
            "ring",
            assert(Accounts.check_login("@frodo"))
        },
        {
            "frodo",
            "  ",
            "ring",
            "ring",
            assert(Accounts.check_name("  "))
        },
        {
            "frodo",
            "Frodo",
            "",
            "",
            assert(Accounts.check_password(""))
        },
        {
            "frodo",
            "Frodo",
            "ring",
            "rings",
            "The passwords differ"
        },
        {
            "",
            "",
            "",
            "x",
            assert(Accounts.check_login(""))
        }
    }
    for _, refusal in ipairs(refusals) do
        with_screen(function(side)
            fill(side, refusal[1], refusal[2], refusal[3], refusal[4])
            click(side, "Create Account")
            test.assert_deep_eq(side.notifications.messages, {
                refusal[5]
            }, "the reason for " .. table.concat(refusal, "|", 1, 4))
            test.assert_deep_eq(side.session.sign_ups, {})
        end)
    end
end)

test.case("Back goes back through the backstack", function()
    with_screen(function(side)
        local backs = 0
        side.app.backstack_manager:push(function()
            backs = backs + 1
        end)
        click(side, "Back")
        test.assert_eq(backs, 1)
        test.assert_eq(side.app.backstack_manager:get_top(), nil)
        test.assert_deep_eq(side.session.sign_ups, {})
    end)
end)

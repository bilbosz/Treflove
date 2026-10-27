local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Accounts = require("data.accounts")
local Control = require("controls.control")
local SignUpScreen = require("login.sign-up-screen")
local Input = require("ui.input")
local BackstackManager = require("utils.backstack-manager")

---@class TestSignUpRequest
---@field login string
---@field name string
---@field password string

---@class TestSignUpSession: Session
---@field sign_ups TestSignUpRequest[]
local TestSignUpSession = class("TestSignUpSession")

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

---@return TestSignUpSide
local function show_screen()
    mocks.ensure_love_graphics()
    mocks.ensure_love_math()
    local app_mock = mocks.install_app()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500
    local notifications = mocks.make_notification_manager()
    app_mock.notification_manager = notifications
    app_mock.backstack_manager = BackstackManager()
    local session = TestSignUpSession()
    local screen = SignUpScreen(session)
    screen:show()
    return {
        app = app_mock,
        session = session,
        notifications = notifications,
        screen = screen
    }
end

---@param side TestSignUpSide
local function finish(side)
    lifetime.destroy(side.screen)
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

---@param side TestSignUpSide
---@return TextInput[] In draw order: the login, the name, the password, the repeat
local function inputs(side)
    local found = {}
    collect(side.screen:get_control(), "TextInput", found)
    return found --[[@as TextInput[] ]]
end

---@param side TestSignUpSide
---@param class_name "Text"|"TextButton"
---@return string[] The texts of the controls of `class_name`, in draw order
local function texts(side, class_name)
    local found = {}
    collect(side.screen:get_control(), class_name, found)
    local result = {}
    for _, ctrl in ipairs(found --[[@as Text[] ]] ) do
        table.insert(result, ctrl:get_text())
    end
    return result
end

---@param side TestSignUpSide
---@param ctrl Control
local function click(side, ctrl)
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    local manager = side.app.button_event_manager
    manager:dispatch_pointer_move(x, y, 1)
    manager:dispatch_pointer_down(x, y, 1)
    manager:dispatch_pointer_up(x, y, 1)
end

---@param side TestSignUpSide
---@param caption string
local function click_button(side, caption)
    local found = {}
    collect(side.screen:get_control(), "TextButton", found)
    for _, button in ipairs(found --[[@as TextButton[] ]] ) do
        if button:get_text() == caption then
            click(side, button)
            return
        end
    end
    error("no button " .. caption)
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

---@param side TestSignUpSide
---@param fn fun(side: TestSignUpSide)
local function with_screen(side, fn)
    ---@type boolean, any
    local ok, err = pcall(fn, side)
    finish(side)
    if not ok then
        error(err, 0)
    end
end

test.suite("SignUpScreen")

test.case("the title, the four fields with their captions, the two password fields masked, then the buttons", function()
    with_screen(show_screen(), function(side)
        test.assert_deep_eq(texts(side, "Text"), {
            "Sign Up",
            "Login",
            "Name",
            "Password",
            "Repeat"
        })
        test.assert_deep_eq(texts(side, "TextButton"), {
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
    with_screen(show_screen(), function(side)
        fill(side, "frodo", "Frodo", "ring", "ring")
        click_button(side, "Create Account")
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
    with_screen(show_screen(), function(side)
        fill(side, "frodo", "Frodo", "ring", "ring")
        local repeat_field = inputs(side)[4]
        click(side, repeat_field)
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
        with_screen(show_screen(), function(side)
            fill(side, refusal[1], refusal[2], refusal[3], refusal[4])
            click_button(side, "Create Account")
            test.assert_deep_eq(side.notifications.messages, {
                refusal[5]
            }, "the reason for " .. table.concat(refusal, "|", 1, 4))
            test.assert_deep_eq(side.session.sign_ups, {})
        end)
    end
end)

test.case("Back goes back through the backstack", function()
    with_screen(show_screen(), function(side)
        local backs = 0
        side.app.backstack_manager:push(function()
            backs = backs + 1
        end)
        click_button(side, "Back")
        test.assert_eq(backs, 1)
        test.assert_eq(side.app.backstack_manager:get_top(), nil)
        test.assert_deep_eq(side.session.sign_ups, {})
    end)
end)

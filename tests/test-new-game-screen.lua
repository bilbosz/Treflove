local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local NewGameScreen = require("screens.new-game-screen")
local Session = require("game.session")

---@class TestNewGameSession: Session
---@field calls string[] The session calls the screen made, in order
local TestNewGameSession = class("TestNewGameSession", Session)

function TestNewGameSession:init()
    self.calls = {}
end

---@param name string
function TestNewGameSession:create_game(name)
    table.insert(self.calls, "create_game " .. name)
end

---@param fn fun(screen: NewGameScreen, session: TestNewGameSession, notifications: TestNotificationManager)
local function with_screen(fn)
    local app_mock = menu_client.install()
    local session = TestNewGameSession()
    local screen = NewGameScreen(session)
    menu_client.with_screen(screen, function()
        fn(screen, session, app_mock.notification_manager --[[@as TestNotificationManager]] )
    end)
end

---@param screen NewGameScreen
---@param name string
local function type_name(screen, name)
    menu_client.click(menu_client.find_all(screen, "TextInput")[1])
    app.text_event_manager:text_input(name)
end

test.suite("NewGameScreen")

test.case("titled New Game: a Name field, Create and Back", function()
    with_screen(function(screen)
        test.assert_eq(#menu_client.find_all(screen, "TextInput"), 1)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Create",
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "New Game",
            "Name"
        })
    end)
end)

test.case("Create asks the session to create the game under the name as typed", function()
    with_screen(function(screen, session, notifications)
        type_name(screen, "The Shire")
        menu_client.click(menu_client.button(screen, "Create"))
        test.assert_deep_eq(session.calls, {
            "create_game The Shire"
        })
        test.assert_deep_eq(notifications.messages, {})
    end)
end)

test.case("Enter in the field creates the game", function()
    with_screen(function(screen, session)
        type_name(screen, "Old Town")
        app.text_event_manager:key_pressed("return")
        test.assert_deep_eq(session.calls, {
            "create_game Old Town"
        })
    end)
end)

test.case("a name with no letter or digit is refused with the reason, nothing asked of the session", function()
    with_screen(function(screen, session, notifications)
        menu_client.click(menu_client.button(screen, "Create"))
        type_name(screen, " -!- ")
        app.text_event_manager:key_pressed("return")
        test.assert_deep_eq(notifications.messages, {
            "A game needs a name with a letter or a digit",
            "A game needs a name with a letter or a digit"
        })
        test.assert_deep_eq(session.calls, {})
    end)
end)

test.case("Back goes back through the back stack", function()
    with_screen(function(screen, session)
        local backs = 0
        app.backstack_manager:push(function()
            backs = backs + 1
        end)
        menu_client.click(menu_client.button(screen, "Back"))
        test.assert_eq(backs, 1)
        test.assert_deep_eq(session.calls, {})
    end)
end)

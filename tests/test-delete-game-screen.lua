local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local DeleteGameScreen = require("screens.delete-game-screen")
local Session = require("game.session")

---@class TestDeleteGameSession: Session
---@field calls string[] The session calls the screen made, in order
local TestDeleteGameSession = class("TestDeleteGameSession", Session)

function TestDeleteGameSession:init()
    self.calls = {}
end

---@param id string
function TestDeleteGameSession:delete_game(id)
    table.insert(self.calls, "delete_game " .. id)
end

---@param fn fun(screen: DeleteGameScreen, session: TestDeleteGameSession, notifications: TestNotificationManager)
local function with_screen(fn)
    local app_mock = menu_client.install()
    local session = TestDeleteGameSession()
    local screen = DeleteGameScreen(session)
    menu_client.with_screen(screen, function()
        fn(screen, session, app_mock.notification_manager --[[@as TestNotificationManager]] )
    end)
end

---@param screen DeleteGameScreen
---@param name string
local function type_name(screen, name)
    menu_client.click(menu_client.find_all(screen, "TextInput")[1])
    app.text_event_manager:text_input(name)
end

test.suite("DeleteGameScreen")

test.case("titled Delete Game: a Name field, Delete and Back", function()
    with_screen(function(screen)
        test.assert_eq(#menu_client.find_all(screen, "TextInput"), 1)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Delete",
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Delete Game",
            "Name"
        })
    end)
end)

test.case("Delete asks the session to delete the game whose id the typed name makes", function()
    with_screen(function(screen, session, notifications)
        type_name(screen, "The Shire!")
        menu_client.click(menu_client.button(screen, "Delete"))
        test.assert_deep_eq(session.calls, {
            "delete_game the-shire"
        })
        test.assert_deep_eq(notifications.messages, {})
    end)
end)

test.case("Enter in the field deletes the game", function()
    with_screen(function(screen, session)
        type_name(screen, "Meadow")
        app.text_event_manager:key_pressed("return")
        test.assert_deep_eq(session.calls, {
            "delete_game meadow"
        })
    end)
end)

test.case("a name that makes no id is refused with the reason, nothing asked of the session", function()
    with_screen(function(screen, session, notifications)
        menu_client.click(menu_client.button(screen, "Delete"))
        type_name(screen, " -!- ")
        app.text_event_manager:key_pressed("return")
        test.assert_deep_eq(notifications.messages, {
            "Type the name of the game to delete",
            "Type the name of the game to delete"
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

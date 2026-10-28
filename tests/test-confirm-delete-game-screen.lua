local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local ConfirmDeleteGameScreen = require("screens.confirm-delete-game-screen")
local Session = require("game.session")

---@class TestConfirmDeleteGameSession: Session
---@field calls string[] The session calls the screen made, in order
local TestConfirmDeleteGameSession = class("TestConfirmDeleteGameSession", Session)

function TestConfirmDeleteGameSession:init()
    self.calls = {}
end

---@param id string
function TestConfirmDeleteGameSession:delete_game(id)
    table.insert(self.calls, "delete_game " .. id)
end

---@param fn fun(screen: ConfirmDeleteGameScreen, session: TestConfirmDeleteGameSession)
local function with_screen(fn)
    menu_client.install()
    local session = TestConfirmDeleteGameSession()
    local screen = ConfirmDeleteGameScreen(session, "the-shire", "The Shire")
    menu_client.with_screen(screen, function()
        fn(screen, session)
    end)
end

test.suite("ConfirmDeleteGameScreen")

test.case("titled with the question about the game by its name: Yes and No", function()
    with_screen(function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Yes",
            "No"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Are you sure to delete \"The Shire\" game?"
        })
    end)
end)

test.case("Yes asks the session to delete the game by its id", function()
    with_screen(function(screen, session)
        menu_client.click(menu_client.button(screen, "Yes"))
        test.assert_deep_eq(session.calls, {
            "delete_game the-shire"
        })
    end)
end)

test.case("No goes back through the back stack, nothing asked of the session", function()
    with_screen(function(screen, session)
        local backs = 0
        app.backstack_manager:push(function()
            backs = backs + 1
        end)
        menu_client.click(menu_client.button(screen, "No"))
        test.assert_eq(backs, 1)
        test.assert_deep_eq(session.calls, {})
    end)
end)

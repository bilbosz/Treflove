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
---@param name string
function TestDeleteGameSession:confirm_delete_game(id, name)
    table.insert(self.calls, "confirm_delete_game " .. id .. " " .. name)
end

---@return GameInfo[]
local function two_games()
    return {
        {
            id = "meadow",
            name = "Meadow",
            member = true,
            deletable = true
        },
        {
            id = "the-shire",
            name = "The Shire",
            member = true,
            deletable = true
        }
    }
end

---@param games GameInfo[]
---@param fn fun(screen: DeleteGameScreen, session: TestDeleteGameSession)
local function with_screen(games, fn)
    menu_client.install()
    local session = TestDeleteGameSession()
    local screen = DeleteGameScreen(session, games)
    menu_client.with_screen(screen, function()
        fn(screen, session)
    end)
end

test.suite("DeleteGameScreen")

test.case("titled Delete Game: one button per game, captioned by its name in the order given, then Back", function()
    with_screen(two_games(), function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Meadow",
            "The Shire",
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Delete Game"
        })
    end)
end)

test.case("a click on a game asks the session for the question about it", function()
    with_screen(two_games(), function(screen, session)
        menu_client.click(menu_client.button(screen, "The Shire"))
        test.assert_deep_eq(session.calls, {
            "confirm_delete_game the-shire The Shire"
        })
    end)
end)

test.case("with no game to delete, a line says so above Back", function()
    with_screen({}, function(screen, session)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Delete Game",
            "No games to delete"
        })
        test.assert_deep_eq(session.calls, {})
    end)
end)

test.case("Back goes back through the back stack", function()
    with_screen(two_games(), function(screen, session)
        local backs = 0
        app.backstack_manager:push(function()
            backs = backs + 1
        end)
        menu_client.click(menu_client.button(screen, "Back"))
        test.assert_eq(backs, 1)
        test.assert_deep_eq(session.calls, {})
    end)
end)

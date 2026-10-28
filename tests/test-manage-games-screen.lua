local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local ManageGamesScreen = require("screens.manage-games-screen")
local Session = require("game.session")

---@class TestManageGamesSession: Session
---@field calls string[] The session calls the screen made, in order
local TestManageGamesSession = class("TestManageGamesSession", Session)

function TestManageGamesSession:init()
    self.calls = {}
end

function TestManageGamesSession:show_new_game()
    table.insert(self.calls, "show_new_game")
end

function TestManageGamesSession:show_games()
    table.insert(self.calls, "show_games")
end

function TestManageGamesSession:show_delete_game()
    table.insert(self.calls, "show_delete_game")
end

---@param fn fun(screen: ManageGamesScreen, session: TestManageGamesSession)
local function with_screen(fn)
    menu_client.install()
    local session = TestManageGamesSession()
    local screen = ManageGamesScreen(session)
    menu_client.with_screen(screen, function()
        fn(screen, session)
    end)
end

---@param screen ManageGamesScreen
---@param caption string
local function click(screen, caption)
    menu_client.click(menu_client.button(screen, caption))
end

test.suite("ManageGamesScreen")

test.case("titled Manage Games: New Game, Join Game, Delete Game and Back", function()
    with_screen(function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "New Game",
            "Join Game",
            "Delete Game",
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Manage Games"
        })
    end)
end)

test.case("each entry asks the session for its screen", function()
    with_screen(function(screen, session)
        click(screen, "New Game")
        click(screen, "Join Game")
        click(screen, "Delete Game")
        test.assert_deep_eq(session.calls, {
            "show_new_game",
            "show_games",
            "show_delete_game"
        })
    end)
end)

test.case("Back goes back through the back stack", function()
    with_screen(function(screen, session)
        local backs = 0
        app.backstack_manager:push(function()
            backs = backs + 1
        end)
        click(screen, "Back")
        test.assert_eq(backs, 1)
        test.assert_eq(app.backstack_manager:get_top(), nil)
        test.assert_deep_eq(session.calls, {})
    end)
end)

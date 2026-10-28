local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local GamesMenuScreen = require("screens.games-menu-screen")
local Session = require("game.session")

---@class TestGamesMenuSession: Session
---@field calls string[] The session calls the screen made, in order
local TestGamesMenuSession = class("TestGamesMenuSession", Session)

function TestGamesMenuSession:init()
    self.calls = {}
end

function TestGamesMenuSession:show_new_game()
    table.insert(self.calls, "show_new_game")
end

function TestGamesMenuSession:show_join_game()
    table.insert(self.calls, "show_join_game")
end

function TestGamesMenuSession:show_delete_game()
    table.insert(self.calls, "show_delete_game")
end

---@param fn fun(screen: GamesMenuScreen, session: TestGamesMenuSession)
local function with_screen(fn)
    menu_client.install()
    local session = TestGamesMenuSession()
    local screen = GamesMenuScreen(session)
    menu_client.with_screen(screen, function()
        fn(screen, session)
    end)
end

---@param screen GamesMenuScreen
---@param caption string
local function click(screen, caption)
    menu_client.click(menu_client.button(screen, caption))
end

test.suite("GamesMenuScreen")

test.case("titled Games: Join, Create, Delete and Back", function()
    with_screen(function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Join",
            "Create",
            "Delete",
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Games"
        })
    end)
end)

test.case("each entry asks the session for its screen", function()
    with_screen(function(screen, session)
        click(screen, "Join")
        click(screen, "Create")
        click(screen, "Delete")
        test.assert_deep_eq(session.calls, {
            "show_join_game",
            "show_new_game",
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

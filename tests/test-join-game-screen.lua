local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local JoinGameScreen = require("screens.join-game-screen")
local Session = require("game.session")

---@class TestJoinGameSession: Session
---@field calls string[] The session calls the screen made, in order
local TestJoinGameSession = class("TestJoinGameSession", Session)

function TestJoinGameSession:init()
    self.calls = {}
end

---@param id string
function TestJoinGameSession:join_game(id)
    table.insert(self.calls, "join_game " .. id)
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
            member = false,
            deletable = false
        }
    }
end

---@param games GameInfo[]
---@param fn fun(screen: JoinGameScreen, session: TestJoinGameSession)
local function with_screen(games, fn)
    menu_client.install()
    local session = TestJoinGameSession()
    local screen = JoinGameScreen(session, games)
    menu_client.with_screen(screen, function()
        fn(screen, session)
    end)
end

---@param screen JoinGameScreen
---@param caption string
local function click(screen, caption)
    menu_client.click(menu_client.button(screen, caption))
end

test.suite("JoinGameScreen")

test.case("one button per game, captioned by its name in the order given, then Back", function()
    with_screen(two_games(), function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Meadow",
            "The Shire",
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Join Game"
        }, "the title, no line for an empty list")
    end)
end)

test.case("a click on a game joins it by its id", function()
    with_screen(two_games(), function(screen, session)
        click(screen, "The Shire")
        click(screen, "Meadow")
        test.assert_deep_eq(session.calls, {
            "join_game the-shire",
            "join_game meadow"
        })
    end)
end)

test.case("Back goes back through the back stack", function()
    with_screen(two_games(), function(screen, session)
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

test.case("with no games, a line says so above the buttons", function()
    with_screen({}, function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Back"
        })
        test.assert_deep_eq(menu_client.texts(screen), {
            "Join Game",
            "No games yet"
        })
        local line = menu_client.find_all(screen, "Text")[2]
        local _, line_bottom = select(3, line:get_global_aabb():get_bounds())
        local _, button_top = menu_client.button(screen, "Back"):get_global_aabb():get_bounds()
        test.assert_true(line_bottom <= button_top, "the line is above Back")
    end)
end)

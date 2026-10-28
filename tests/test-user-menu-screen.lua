local test = require("tests.lib.test")
local menu_client = require("tests.lib.menu-client")
local Session = require("game.session")
local UserMenuScreen = require("screens.user-menu-screen")

---@class TestUserMenuSession: Session
---@field calls string[] The session calls the screen made, in order
local TestUserMenuSession = class("TestUserMenuSession", Session)

function TestUserMenuSession:init()
    self.calls = {}
end

function TestUserMenuSession:show_games_menu()
    table.insert(self.calls, "show_games_menu")
end

function TestUserMenuSession:logout()
    table.insert(self.calls, "logout")
end

---@param fn fun(screen: UserMenuScreen, session: TestUserMenuSession)
local function with_screen(fn)
    menu_client.install()
    local session = TestUserMenuSession()
    local screen = UserMenuScreen(session)
    menu_client.with_screen(screen, function()
        fn(screen, session)
    end)
end

test.suite("UserMenuScreen")

test.case("Games, Options, Log Out and Quit", function()
    with_screen(function(screen)
        test.assert_deep_eq(menu_client.captions(screen), {
            "Games",
            "Options",
            "Log Out",
            "Quit"
        })
    end)
end)

test.case("Games asks the session for the Games screen", function()
    with_screen(function(screen, session)
        menu_client.click(menu_client.button(screen, "Games"))
        test.assert_deep_eq(session.calls, {
            "show_games_menu"
        })
    end)
end)

test.case("Log Out logs the session out", function()
    with_screen(function(screen, session)
        menu_client.click(menu_client.button(screen, "Log Out"))
        test.assert_deep_eq(session.calls, {
            "logout"
        })
    end)
end)

test.case("Options shows the options screen, whose Back shows the menu again", function()
    with_screen(function(screen, session)
        menu_client.click(menu_client.button(screen, "Options"))
        local options = app.screen_manager:get_screen()
        test.assert_eq(get_class_name_of(options), "OptionsMenuScreen")
        menu_client.click(menu_client.button(assert(options), "Back"))
        test.assert_eq(app.screen_manager:get_screen(), screen)
        test.assert_eq(app.backstack_manager:get_top(), nil)
        test.assert_deep_eq(session.calls, {})
    end)
end)

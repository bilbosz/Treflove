local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Utils = require("utils.utils")
local AssetManager = require("data.asset-manager")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local UploadAssetRp = require("data.upload-asset-rp")
local AssetsPanel = require("game.assets.assets-panel")
local PreviewArea = require("game.assets.preview-area.preview-area")
local GameDataRp = require("game.game-data-rp")
local GameScreen = require("game.game-screen")
local Session = require("game.session")
local LoginRp = require("login.login-rp")
local LoginScreen = require("login.login-screen")
local LogoutRp = require("login.logout-rp")
local Connection = require("networking.connection")
local ConnectionManager = require("networking.connection-manager")
local OptionsMenuScreen = require("screens.options-menu-screen")
local ScreenManager = require("screens.screen-manager")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")
local ButtonEventManager = require("ui.button-event")
local TextEventManager = require("ui.text-event")
local BackstackManager = require("utils.backstack-manager")
local Control = require("controls.control")

-- lua-lifetime: the whole ownership tree of docs/lifetimes.md, driven end to
-- end: a client and a server in one process, connected over fake channels
-- back to back, with `app` swapped between them for each frame (as the
-- lua-lifetime trial harness does). Connect (the auto-login), the menu, the
-- game, back, the options, logout, disconnect, and the teardown love.quit
-- runs: every step asserts what is shown, what is on the back stack, and
-- the whole order of the `release` calls it caused.

---@type string[]
local destroy_errors = {}
-- lua-lifetime reports an error raised by a destructor other than the first
-- of a cascade here (lib/lua-lifetime/docs/02-semantics.md, "Errors in
-- destructors and `destroyerror`"); every case asserts there was none.
-- luacheck: globals destroyerror
---@param err any
---@diagnostic disable-next-line: lowercase-global
function destroyerror(err)
    table.insert(destroy_errors, tostring(err))
end

-- Set by the client's own, bottom back entry (Client:load's quit).
local quit_requested = false

---The server's stored `auth` for adam/krause: what LoginRp computes on both
---sides from the deterministic fakes (login/login.lua, login/login-rp.lua).
---@return string
local function server_auth()
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    app = {
        is_client = true,
        is_server = false
    }
    local client = Utils.hash("adam" .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. "krause")
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    app = {
        is_client = false,
        is_server = true
    }
    return Utils.hash("adam" .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. client)
end

---The server's persisted state: one page with one token, and the player.
---@param auth string
---@return table
local function game_data(auth)
    return {
        players = {
            adam = {
                auth = auth
            }
        },
        game = {
            page = "P"
        },
        pages = {
            P = {
                name = "P",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "T"
                }
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            },
            diameter = {
                title = "Diameter",
                type = "number"
            },
            avatar = {
                title = "Avatar",
                type = "image"
            },
            owners = {
                title = "Owners",
                type = "array"
            },
            position = {
                title = "Position",
                type = "array"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 3,
                avatar = "token/t.png",
                owners = {
                    "adam"
                },
                position = {
                    1,
                    2
                }
            }
        }
    }
end

---The in-memory file system of both sides: the server's assets, which its
---asset manager mounts under "s", and the client's copies, so that nothing
---is missing when the game is joined.
---@return table<string, string>
local function files()
    return {
        ["server/assets/world/w.png"] = "W",
        ["server/assets/token/t.png"] = "T",
        ["c/assets/world/w.png"] = "W",
        ["c/assets/token/t.png"] = "T"
    }
end

---@class TestNotificationManager: NotificationManager
---@field messages string[]
local TestNotificationManager = class("TestNotificationManager")

function TestNotificationManager:init()
    self.messages = {}
end

---@param message string
function TestNotificationManager:notify(message)
    table.insert(self.messages, message)
end

---A client app: Client:init's managers that the flow touches, and the
---connection callbacks of Client:load. `app` is the new app afterwards.
---@return AppMock
local function make_client()
    local client = mocks.make_app()
    app = client
    client.root = Control()
    client.width, client.height = 2000, 1500
    client.screen_manager = ScreenManager()
    client.backstack_manager = BackstackManager()
    client.button_event_manager = ButtonEventManager()
    client.text_event_manager = TextEventManager(mocks.make_keyboard())
    ---@diagnostic disable-next-line: assign-type-mismatch
    client.notification_manager = TestNotificationManager()
    client.asset_manager = AssetManager()
    client.connection_manager = ConnectionManager("localhost", "8080")
    client.session = nil
    -- Client:load, without the connector's thread
    quit_requested = false
    client.backstack_manager:push(function()
        quit_requested = true
    end)
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_connect = function(connection)
        client.session = Session(connection):attach_lifetime(connection)
    end
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_disconnect = function()
        client.session = nil
        client.data = nil
    end
    return client
end

---A server app with the data above; `app` is the new app afterwards.
---@param auth string
---@return AppMock
---@return table<Connection, Session> sessions
local function make_server(auth)
    local server = mocks.make_app({
        is_client = false,
        is_server = true
    })
    app = server
    server.data = game_data(auth)
    server.asset_manager = AssetManager()
    server.connection_manager = ConnectionManager("localhost", "8080")
    local sessions = {}
    ---@diagnostic disable-next-line: invisible
    server.connection_manager._on_connect = function(connection)
        sessions[connection] = Session(connection):attach_lifetime(connection)
    end
    ---@diagnostic disable-next-line: invisible
    server.connection_manager._on_disconnect = function(connection)
        sessions[connection] = nil
    end
    return server, sessions
end

---One frame of `some_app`: what love.update does with the update event, the
---connections' `on_update` included.
---@param some_app AppMock
local function frame(some_app)
    app = some_app
    some_app.update_event:trigger(0.016)
end

---Connect: each side adds its end of a pair of fake channels, back to back,
---as its connector would. The client's session sends the login request.
---@param client AppMock
---@param server AppMock
---@return Connection client_connection
---@return Connection server_connection
local function connect(client, server)
    local client_to_server = mocks.make_channel()
    local server_to_client = mocks.make_channel()
    app = server
    server.connection_manager:add_connection(client_to_server, mocks.make_thread(), server_to_client, mocks.make_thread())
    local server_connection = assert(next(server.connection_manager:get_connections()))
    app = client
    client.connection_manager:add_connection(server_to_client, mocks.make_thread(), client_to_server, mocks.make_thread())
    return client.session:get_connection(), server_connection
end

local CLASSES = {
    Connection = Connection,
    LoginRp = LoginRp,
    LogoutRp = LogoutRp,
    GameDataRp = GameDataRp,
    UploadAssetRp = UploadAssetRp,
    DownloadAssetRp = DownloadAssetRp,
    DownloadMissingAssetsRp = DownloadMissingAssetsRp,
    LoginScreen = LoginScreen,
    UserMenuScreen = UserMenuScreen,
    OptionsMenuScreen = OptionsMenuScreen,
    WaitingScreen = WaitingScreen,
    GameScreen = GameScreen,
    AssetsPanel = AssetsPanel,
    PreviewArea = PreviewArea
}

---Log `Class:release(reason)` of every class above into `log` while `fn`
---runs; the originals are restored afterwards, whatever `fn` did. The
---collector is stopped meanwhile: a death by `reachable` (a replaced waiting
---screen, an earlier case's leftovers) is the collector's and would land in
---the log at a time of its choosing; each case collects at its end instead
---(lib/lua-lifetime/CLAUDE.md, rule 3).
---@param log string[]
---@param fn fun()
local function with_release_log(log, fn)
    local originals = {}
    for name, cls in pairs(CLASSES) do
        local release = cls.release
        originals[name] = release
        cls.release = function(self, reason)
            table.insert(log, name .. ":release(" .. tostring(reason) .. ")")
            return release(self, reason)
        end
    end
    collectgarbage("stop")
    local ok, err = pcall(fn)
    collectgarbage("restart")
    for name, cls in pairs(CLASSES) do
        cls.release = originals[name]
    end
    if not ok then
        error(err, 0)
    end
end

---The class names of `objects`, for asserting a dependents list; a hook or
---a token (a string metatable) by its kind.
---@param objects table[]
---@return string[]
local function class_names(objects)
    local names = {}
    for _, object in ipairs(objects) do
        local kind = getmetatable(object)
        table.insert(names, type(kind) == "string" and kind or get_class_name_of(object))
    end
    return names
end

---`class_names` without the hooks: a form screen carries one per input
---(ui/input.lua) and, while shown, the screen manager's.
---@param objects table[]
---@return string[]
local function class_names_but_hooks(objects)
    local names = {}
    for _, name in ipairs(class_names(objects)) do
        if name ~= "hook" then
            table.insert(names, name)
        end
    end
    return names
end

---Everything up to the game screen: connect (the auto-login request), the
---login answered, the menu shown and the game joined at once, the game data
---and the (empty) asset download answered, the game screen shown.
---@return AppMock client
---@return AppMock server
---@return Connection client_connection
---@return Connection server_connection
---@return table<Connection, Session> sessions
---@return table|nil previous_filesystem
local function enter_the_game()
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    mocks.ensure_love_thread()
    local previous = mocks.install_love_filesystem(files())
    local auth = server_auth()
    local server, sessions = make_server(auth)
    local client = make_client()
    local client_connection, server_connection = connect(client, server)
    test.assert_eq(get_class_name_of(client.session), "Session")
    test.assert_false(client.session:is_logged_in())

    frame(server) -- the login request is answered
    frame(client) -- logged in: the menu, then the game joined at once
    test.assert_true(client.session:is_logged_in())
    test.assert_true(sessions[server_connection]:is_logged_in())
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "Successfully logged in as adam"
    })
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen")

    frame(server) -- the game data
    frame(client)
    test.assert_eq(client.data.game.page, "P")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen")

    frame(server) -- the missing assets: none
    frame(client)
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "GameScreen")
    return client, server, client_connection, server_connection, sessions, previous
end

---Ends a case as a quit would: both sides remove their connections
---(ConnectionManager:remove_all, what love.quit calls), then what the flow
---left unowned (the inputs of dead screens, the replaced waiting screens) is
---collected while the client app is still the global, and the fake file
---system is put back.
---@param client AppMock
---@param server AppMock
---@param previous table|nil
local function finish(client, server, previous)
    app = server
    server.connection_manager:remove_all()
    app = client
    client.connection_manager:remove_all()
    collectgarbage("collect")
    collectgarbage("collect")
    mocks.restore_love_filesystem(previous)
    test.assert_deep_eq(destroy_errors, {}, "no destructor raised")
end

test.suite("Lifetimes end to end")

test.case("connect and log in: the session owns the period, which owns the menu, its back entry and the game screen", function()
    local client, server, client_connection, _, _, previous = enter_the_game()
    local session = client.session
    test.assert_deep_eq(class_names(lifetime.dependents(client_connection)), {
        "Session"
    })
    test.assert_deep_eq(class_names(lifetime.dependents(session)), {
        "Login",
        "GameDataRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "hook",
        "token"
    })
    ---@diagnostic disable-next-line: invisible
    local period = session._period
    test.assert_eq(lifetime.format(period), "token logged in")
    test.assert_deep_eq(class_names(lifetime.dependents(period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GameScreen"
    })
    local game_screen = client.screen_manager:get_screen()
    local game_dependents = lifetime.dependents(game_screen)
    test.assert_deep_eq(class_names_but_hooks(game_dependents), {
        "AssetsPanel",
        "BackstackEntry"
    })
    test.assert_eq(client.backstack_manager:get_top(), game_dependents[#game_dependents], "the way back is the game screen's entry")
    finish(client, server, previous)
end)

test.case("back from the game: the menu is shown again, the game screen dies with its panels, newest first", function()
    local client, server, _, _, _, previous = enter_the_game()
    local game_screen = client.screen_manager:get_screen() --[[@as GameScreen]]
    local inputs_of_game = {}
    ---@diagnostic disable-next-line: invisible
    for _, input in ipairs(game_screen._inputs) do
        table.insert(inputs_of_game, input)
    end
    test.assert_true(#inputs_of_game > 0, "the panels' fields and buttons are the game screen's inputs")
    local log = {}
    with_release_log(log, function()
        client.backstack_manager:back()
    end)
    test.assert_deep_eq(log, {
        "GameScreen:release(destroy)",
        "AssetsPanel:release(anchor)",
        "PreviewArea:release(anchor)"
    })
    test.assert_false(lifetime.alive(game_screen))
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    test.assert_deep_eq(client.root:get_children(), {
        client.screen_manager:get_screen():get_control()
    }, "only the menu is on the root")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(client.session._game_screen, nil)
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry"
    }, "the dead game screen left the period")
    for _, input in ipairs(inputs_of_game) do
        test.assert_true(lifetime.alive(input), "an input is not the form's to destroy; its hook died with the form")
        test.assert_deep_eq(lifetime.dependents(input), {})
    end
    test.assert_deep_eq(lifetime.dependents(game_screen), {}, "a dead anchor holds nothing")
    finish(client, server, previous)
end)

test.case("the options: one screen per menu, a way back per visit, both the menu's", function()
    local client, server, _, _, _, previous = enter_the_game()
    client.backstack_manager:back()
    local menu = client.screen_manager:get_screen() --[[@as UserMenuScreen]]
    local logout_entry = client.backstack_manager:get_top()

    menu:options()
    local options = client.screen_manager:get_screen()
    test.assert_eq(get_class_name_of(options), "OptionsMenuScreen")
    local menu_dependents = lifetime.dependents(menu)
    test.assert_deep_eq(class_names_but_hooks(menu_dependents), {
        "OptionsMenuScreen",
        "BackstackEntry"
    })
    local way_back = client.backstack_manager:get_top()
    test.assert_eq(way_back, menu_dependents[#menu_dependents])

    client.backstack_manager:back()
    test.assert_eq(client.screen_manager:get_screen(), menu)
    test.assert_false(lifetime.alive(way_back))
    test.assert_eq(client.backstack_manager:get_top(), logout_entry)

    menu:options()
    test.assert_eq(client.screen_manager:get_screen(), options, "the same options screen on the second visit")
    test.assert_deep_eq(class_names_but_hooks(lifetime.dependents(menu)), {
        "OptionsMenuScreen",
        "BackstackEntry"
    })
    client.backstack_manager:back()
    test.assert_eq(client.screen_manager:get_screen(), menu)
    finish(client, server, previous)
end)

test.case("logout: the period dies with the menu, the options and the back entries; the login screen is the session's", function()
    local client, server, _, _, _, previous = enter_the_game()
    client.backstack_manager:back()
    local menu = client.screen_manager:get_screen() --[[@as UserMenuScreen]]
    menu:options()
    local options = client.screen_manager:get_screen()
    test.assert_eq(get_class_name_of(options), "OptionsMenuScreen")
    client.backstack_manager:back()
    ---@diagnostic disable-next-line: invisible
    local period = client.session._period

    local log = {}
    with_release_log(log, function()
        app = client
        client.session:logout()
        frame(server)
        test.assert_deep_eq(log, {}, "nothing dies before the response is in")
        frame(client)
    end)
    test.assert_deep_eq(log, {
        "UserMenuScreen:release(anchor)",
        "OptionsMenuScreen:release(anchor)"
    })
    test.assert_false(lifetime.alive(period))
    test.assert_false(lifetime.alive(menu))
    test.assert_false(lifetime.alive(options))
    test.assert_false(client.session:is_logged_in())
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "LoginScreen")
    test.assert_deep_eq(client.root:get_children(), {
        client.screen_manager:get_screen():get_control()
    })
    test.assert_deep_eq(class_names(lifetime.dependents(client.session)), {
        "Login",
        "GameDataRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "hook",
        "LoginScreen"
    }, "the dead period left the session; the login screen lives as long as the session")
    test.assert_eq(get_class_name_of(client.backstack_manager:get_top()), "BackstackEntry")
    client.backstack_manager:back()
    test.assert_true(quit_requested, "only the client's own quit entry is left")
    finish(client, server, previous)
end)

test.case("disconnect: one cascade per side, the connection first, then the session's tree newest first", function()
    local client, server, client_connection, server_connection, sessions, previous = enter_the_game()
    local session = client.session
    local server_session = sessions[server_connection]
    local log = {}
    with_release_log(log, function()
        app = client
        client.connection_manager:remove(client_connection)
    end)
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "GameScreen:release(anchor)",
        "AssetsPanel:release(anchor)",
        "PreviewArea:release(anchor)",
        "UserMenuScreen:release(anchor)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(client_connection))
    test.assert_false(lifetime.alive(session))
    test.assert_eq(client.session, nil)
    test.assert_eq(next(client.connection_manager:get_connections()), nil)
    test.assert_deep_eq(client.root:get_children(), {}, "the game screen hid itself")
    test.assert_eq(client.screen_manager:get_screen(), nil)
    test.assert_eq(get_class_name_of(client.backstack_manager:get_top()), "BackstackEntry")
    client.backstack_manager:back()
    test.assert_true(quit_requested, "the period's and the game's entries left the stack")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(next(client.asset_manager._upload_asset_rp), nil, "the asset manager's entries were cleared by the session's hook")

    log = {}
    with_release_log(log, function()
        app = server
        server.connection_manager:remove(server_connection)
    end)
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(server_session))
    test.assert_eq(sessions[server_connection], nil)
    finish(client, server, previous)
end)

test.case("quit: remove_all tears every connection down in order, as love.quit does before the state closes", function()
    local client, server, client_connection, server_connection, _, previous = enter_the_game()
    local log = {}
    with_release_log(log, function()
        app = server
        server.connection_manager:remove_all()
        app = client
        client.connection_manager:remove_all()
    end)
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)",
        "Connection:release(destroy)",
        "GameScreen:release(anchor)",
        "AssetsPanel:release(anchor)",
        "PreviewArea:release(anchor)",
        "UserMenuScreen:release(anchor)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(client_connection))
    test.assert_false(lifetime.alive(server_connection))
    test.assert_eq(next(client.connection_manager:get_connections()), nil)
    test.assert_eq(next(server.connection_manager:get_connections()), nil)
    finish(client, server, previous)
end)

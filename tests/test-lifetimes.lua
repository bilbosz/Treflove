local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Utils = require("utils.utils")
local Accounts = require("data.accounts")
local Asset = require("data.asset")
local AssetManager = require("data.asset-manager")
local Games = require("data.games")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local UploadAssetRp = require("data.upload-asset-rp")
local AssetUsageList = require("game.assets.workspace.asset-usage-list")
local AssetDetails = require("game.assets.workspace.asset-details")
local AssetList = require("game.assets.workspace.asset-list")
local AssetsWorkspaceScreen = require("game.assets.workspace.assets-workspace-screen")
local PreviewArea = require("game.assets.preview-area.preview-area")
local CreateGameRp = require("game.create-game-rp")
local GameDataRp = require("game.game-data-rp")
local GameScreen = require("game.game-screen")
local ListGamesRp = require("game.list-games-rp")
local Session = require("game.session")
local CreateAccountRp = require("login.create-account-rp")
local LoginRp = require("login.login-rp")
local LoginScreen = require("login.login-screen")
local LogoutRp = require("login.logout-rp")
local SignUpScreen = require("login.sign-up-screen")
local Connection = require("networking.connection")
local ConnectionManager = require("networking.connection-manager")
local GamesScreen = require("screens.games-screen")
local NewGameScreen = require("screens.new-game-screen")
local OptionsMenuScreen = require("screens.options-menu-screen")
local ScreenManager = require("screens.screen-manager")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")
local ButtonEventManager = require("ui.button-event")
local TextButton = require("ui.text-button")
local TextEventManager = require("ui.text-event")
local BackstackManager = require("utils.backstack-manager")
local Control = require("controls.control")

---@type string[]
local destroy_errors = {}
-- luacheck: globals lifetime_destroyerror
---@param obj table|function The dying object (a hook: its function's owner)
---@param err any
function lifetime_destroyerror(obj, err)
    local message = tostring(obj) .. ": " .. tostring(err)
    table.insert(destroy_errors, message)
    io.stderr:write("lifetime_destroyerror: " .. message .. "\n")
end

local quit_requested = false

---@return string
local function server_auth()
    -- whole app mocks: an orphan of an earlier case that the collector finds
    -- meanwhile runs its destructor against the global app
    app = mocks.make_app()
    local client = Utils.hash("adam" .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. "krause")
    app = mocks.make_app({
        is_client = false,
        is_server = true
    })
    return Utils.hash("adam" .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. client)
end

---@return GameData
local function game_data()
    return {
        name = "G",
        players = {
            adam = {
                group = "master"
            }
        },
        groups = {
            master = {
                title = "Game master",
                permissions = {
                    "read",
                    "write"
                }
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

---@return GameData
local function template()
    return {
        name = "",
        game = {
            page = "Table"
        },
        pages = {
            Table = {
                name = "Table",
                width = 20,
                pixel_per_meter = 51.2,
                image = "world/table.png",
                tokens = {
                    "Hero"
                }
            }
        },
        token_properties = {},
        tokens = {
            Hero = {
                name = "Hero",
                diameter = 1,
                avatar = "token/default.png",
                owners = {},
                position = {
                    10,
                    7.5
                }
            }
        },
        players = {},
        groups = {
            master = {
                title = "Game master",
                permissions = {
                    "read",
                    "write"
                }
            }
        }
    }
end

---@param auth string The server-side auth of adam's password
---@param data GameData The game `mocks.GAME_ID`
---@return table<string, string>
local function files(auth, data)
    return {
        ["s/accounts.lua"] = table.to_string({
            adam = {
                name = "Adam",
                auth = auth
            }
        }),
        ["s/games/g/save.lua"] = table.to_string(data),
        ["s/games/g/assets/world/w.png"] = "W",
        ["s/games/g/assets/token/t.png"] = "T",
        ["c/games/g/assets/world/w.png"] = "W",
        ["c/games/g/assets/token/t.png"] = "T",
        ["server/template/save.lua"] = table.to_string(template()),
        ["server/template/assets/world/table.png"] = "TABLE",
        ["server/template/assets/token/default.png"] = "D"
    }
end

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
    client.notification_manager = mocks.make_notification_manager()
    client.asset_manager = AssetManager()
    client.connection_manager = ConnectionManager("localhost", "8080")
    client.session = nil
    quit_requested = false
    client.backstack_manager:push(function()
        quit_requested = true
    end)
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_connect = function(connection)
        local session = Session(connection):attach_lifetime(connection)
        client.session = session
        session:show_login()
    end
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_disconnect = function()
        client.session = nil
        client.data = nil
    end
    return client
end

---@return AppMock
---@return table<Connection, Session> sessions
local function make_server()
    local server = mocks.make_app({
        is_client = false,
        is_server = true
    })
    app = server
    server.accounts = Accounts(Asset("s/accounts.lua"))
    server.games = Games("s/games")
    server.asset_manager = AssetManager()
    server.connection_manager = ConnectionManager("localhost", "8080")
    ---@type table<Connection, Session>
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

---@param some_app AppMock
local function frame(some_app)
    app = some_app
    some_app.update_event:trigger(0.016)
end

---@param client AppMock
---@param server AppMock
---@return Connection client_connection
---@return Connection server_connection
local function connect(client, server)
    local client_to_server = mocks.make_channel()
    local server_to_client = mocks.make_channel()
    app = server
    server.connection_manager:add_connection(client_to_server, server_to_client)
    local server_connection = assert(next(server.connection_manager:get_connections()))
    app = client
    client.connection_manager:add_connection(server_to_client, client_to_server)
    return client.session:get_connection(), server_connection
end

---@type table<string, Class>
local CLASSES = {
    Connection = Connection,
    LoginRp = LoginRp,
    LogoutRp = LogoutRp,
    CreateAccountRp = CreateAccountRp,
    GameDataRp = GameDataRp,
    ListGamesRp = ListGamesRp,
    CreateGameRp = CreateGameRp,
    UploadAssetRp = UploadAssetRp,
    DownloadAssetRp = DownloadAssetRp,
    DownloadMissingAssetsRp = DownloadMissingAssetsRp,
    LoginScreen = LoginScreen,
    SignUpScreen = SignUpScreen,
    UserMenuScreen = UserMenuScreen,
    GamesScreen = GamesScreen,
    NewGameScreen = NewGameScreen,
    OptionsMenuScreen = OptionsMenuScreen,
    WaitingScreen = WaitingScreen,
    GameScreen = GameScreen,
    AssetUsageList = AssetUsageList,
    PreviewArea = PreviewArea,
    AssetsWorkspaceScreen = AssetsWorkspaceScreen,
    AssetList = AssetList,
    AssetDetails = AssetDetails
}

---The collector is stopped meanwhile: a death by `reachable` would land in
---the log at a time of its choosing; each case collects at its end.
---@param log string[]
---@param fn fun()
local function with_release_log(log, fn)
    ---@type table<string, Destructor>
    local originals = {}
    for name, cls in pairs(CLASSES) do
        ---@type Destructor
        local release = cls.release
        originals[name] = release
        ---@param self Object
        ---@param reason lifetime.Reason
        cls.release = function(self, reason)
            table.insert(log, name .. ":release(" .. tostring(reason) .. ")")
            release(self, reason)
        end
    end
    collectgarbage("stop")
    ---@type boolean, any
    local ok, err = pcall(fn)
    collectgarbage("restart")
    for name, cls in pairs(CLASSES) do
        cls.release = originals[name]
    end
    if not ok then
        error(err, 0)
    end
end

---@param objects (table|lifetime.Hook)[] What `lifetime.dependents` gives
---@return string[]
local function class_names(objects)
    local names = {}
    for _, object in ipairs(objects) do
        local kind = getmetatable(object)
        table.insert(names, type(kind) == "string" and kind or get_class_name_of(object))
    end
    return names
end

---@param objects (table|lifetime.Hook)[] What `lifetime.dependents` gives
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

---@param client AppMock
---@param x number
---@param y number
local function move(client, x, y)
    app = client
    client.button_event_manager:dispatch_pointer_move(x, y, 1)
end

---@param client AppMock
---@param ctrl Control
local function click(client, ctrl)
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    move(client, x, y)
    client.button_event_manager:dispatch_pointer_down(x, y, 1)
    client.button_event_manager:dispatch_pointer_up(x, y, 1)
end

---@param screen FormScreen
---@param text string
---@return TextButton
local function button_of(screen, text)
    ---@diagnostic disable-next-line: invisible
    for _, input in ipairs(screen._inputs) do
        if is_instance_of(input, TextButton) then
            ---@cast input TextButton
            if input:get_text() == text then
                return input
            end
        end
    end
    error("no button " .. text)
end

---@class TestFlow
---@field client AppMock
---@field server AppMock
---@field client_connection Connection
---@field server_connection Connection
---@field sessions table<Connection, Session>
---@field previous_filesystem love.filesystem|nil

---@param adjust_data (fun(data: GameData))|nil Changes the server's data before anyone connects
---@return TestFlow flow Connected: the login screen shown, no login sent
local function connect_the_sides(adjust_data)
    destroy_errors = {}
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    mocks.ensure_love_thread()
    local auth = server_auth()
    local data = game_data()
    if adjust_data then
        adjust_data(data)
    end
    local previous = mocks.install_love_filesystem(files(auth, data))
    local server, sessions = make_server()
    local client = make_client()
    local client_connection, server_connection = connect(client, server)
    test.assert_eq(get_class_name_of(client.session), "Session")
    test.assert_false(client.session:is_logged_in())
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "LoginScreen")
    test.assert_eq(client_connection:get_out_channel():getCount(), 0, "no login before the user signs in")
    return {
        client = client,
        server = server,
        client_connection = client_connection,
        server_connection = server_connection,
        sessions = sessions,
        previous_filesystem = previous
    }
end

---@param flow TestFlow
local function log_in(flow)
    local client, server = flow.client, flow.server
    app = client
    client.session:login("adam", "krause")
    frame(server)
    frame(client)
    test.assert_true(client.session:is_logged_in())
    test.assert_true(flow.sessions[flow.server_connection]:is_logged_in())
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "Successfully logged in as adam"
    })
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen", "a login lands on the menu")
end

---@param flow TestFlow The game data requested
local function load_the_game(flow)
    local client, server = flow.client, flow.server
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen")
    frame(server)
    frame(client)
    test.assert_eq(client.data.game.page, "P")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen")

    frame(server)
    frame(client)
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "GameScreen")
end

---@return TestFlow
local function enter_the_game()
    local flow = connect_the_sides()
    log_in(flow)
    app = flow.client
    flow.client.session:join_game(mocks.GAME_ID)
    load_the_game(flow)
    return flow
end

---@param flow TestFlow
local function finish(flow)
    app = flow.server
    flow.server.connection_manager:remove_all()
    app = flow.client
    flow.client.connection_manager:remove_all()
    collectgarbage("collect")
    collectgarbage("collect")
    mocks.restore_love_filesystem(flow.previous_filesystem)
    test.assert_deep_eq(destroy_errors, {}, "no destructor raised")
end

---@param name string
---@param fn fun(flow: TestFlow)
---@param begin (fun(): TestFlow)|nil Defaults to `enter_the_game`
local function flow_case(name, fn, begin)
    test.case(name, function()
        local flow = (begin or enter_the_game)()
        ---@type boolean, any
        local ok, err = pcall(fn, flow)
        finish(flow)
        if not ok then
            error(err, 0)
        end
    end)
end

test.suite("Lifetimes end to end")

flow_case("connect and log in: the session owns the period, which owns the menu, its back entry and the game screen", function(flow)
    local client, client_connection = flow.client, flow.client_connection
    local session = assert(client.session)
    test.assert_deep_eq(class_names(lifetime.dependents(client_connection)), {
        "Session"
    })
    test.assert_deep_eq(class_names(lifetime.dependents(session)), {
        "Login",
        "GameDataRp",
        "ListGamesRp",
        "CreateGameRp",
        "UpdateTokenRp",
        "TokenChangedRp",
        "CreateTokenRp",
        "DeleteTokenRp",
        "TokenCreatedRp",
        "TokenDeletedRp",
        "UpdateEntryRp",
        "EntryChangedRp",
        "CreateEntryRp",
        "DeleteEntryRp",
        "EntryCreatedRp",
        "EntryDeletedRp",
        "GrantsChangedRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "ListAssetsRp",
        "CreateAssetFolderRp",
        "RenameAssetRp",
        "DeleteAssetRp",
        "hook",
        "token"
    })
    ---@diagnostic disable-next-line: invisible
    local period = assert(session._period)
    test.assert_eq(lifetime.format(period), "token logged in")
    test.assert_deep_eq(class_names(lifetime.dependents(period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GameScreen"
    })
    local game_screen = assert(client.screen_manager:get_screen())
    local game_dependents = lifetime.dependents(game_screen)
    test.assert_deep_eq(class_names_but_hooks(game_dependents), {
        "BackstackEntry"
    }, "the panels are the control tree's, not anchored")
    test.assert_eq(client.backstack_manager:get_top(), game_dependents[#game_dependents], "the way back is the game screen's entry")
end)

flow_case("connect: the login screen is the session's; signing in through its fields destroys it at the login and shows the menu, from which the game is joined", function(flow)
    local client, server = flow.client, flow.server
    local login_screen = client.screen_manager:get_screen() --[[@as LoginScreen]]
    test.assert_deep_eq(class_names(lifetime.dependents(client.session)), {
        "Login",
        "GameDataRp",
        "ListGamesRp",
        "CreateGameRp",
        "UpdateTokenRp",
        "TokenChangedRp",
        "CreateTokenRp",
        "DeleteTokenRp",
        "TokenCreatedRp",
        "TokenDeletedRp",
        "UpdateEntryRp",
        "EntryChangedRp",
        "CreateEntryRp",
        "DeleteEntryRp",
        "EntryCreatedRp",
        "EntryDeletedRp",
        "GrantsChangedRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "ListAssetsRp",
        "CreateAssetFolderRp",
        "RenameAssetRp",
        "DeleteAssetRp",
        "hook",
        "LoginScreen"
    }, "the login screen is the session's from the connect on")

    ---@diagnostic disable-next-line: invisible
    local login_input, password_input = login_screen._login_input._input, login_screen._password_input._input
    click(client, login_input)
    client.text_event_manager:text_input("adam")
    click(client, password_input)
    client.text_event_manager:text_input("krause")
    local log = {}
    with_release_log(log, function()
        click(client, button_of(login_screen, "Sign In"))
        frame(server)
        test.assert_deep_eq(log, {}, "nothing dies before the response is in")
        frame(client)
    end)
    test.assert_deep_eq(log, {
        "LoginScreen:release(destroy)"
    }, "logged in: the login screen is over, destroyed rather than left to the collector")
    test.assert_false(lifetime.alive(login_screen))
    test.assert_true(client.session:is_logged_in())
    test.assert_deep_eq(class_names(lifetime.dependents(client.session)), {
        "Login",
        "GameDataRp",
        "ListGamesRp",
        "CreateGameRp",
        "UpdateTokenRp",
        "TokenChangedRp",
        "CreateTokenRp",
        "DeleteTokenRp",
        "TokenCreatedRp",
        "TokenDeletedRp",
        "UpdateEntryRp",
        "EntryChangedRp",
        "CreateEntryRp",
        "DeleteEntryRp",
        "EntryCreatedRp",
        "EntryDeletedRp",
        "GrantsChangedRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "ListAssetsRp",
        "CreateAssetFolderRp",
        "RenameAssetRp",
        "DeleteAssetRp",
        "hook",
        "token"
    }, "the dead login screen left the session")
    local menu = client.screen_manager:get_screen() --[[@as UserMenuScreen]]
    test.assert_eq(get_class_name_of(menu), "UserMenuScreen")
    test.assert_eq(flow.client_connection:get_out_channel():getCount(), 0, "no game data asked for before a game is joined")
    client.session:join_game(mocks.GAME_ID)
    load_the_game(flow)
    move(client, 0, 0)
end, connect_the_sides)

flow_case("disconnect before the login: the login screen dies with the session, newest first", function(flow)
    local client, client_connection = flow.client, flow.client_connection
    local login_screen = client.screen_manager:get_screen()
    local log = {}
    with_release_log(log, function()
        app = client
        client.connection_manager:remove(client_connection)
    end)
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "LoginScreen:release(anchor)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "CreateGameRp:release(anchor)",
        "ListGamesRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "CreateAccountRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(login_screen))
    test.assert_deep_eq(client.root:get_children(), {}, "the login screen hid itself")
    test.assert_eq(client.screen_manager:get_screen(), nil)
end, connect_the_sides)

flow_case("game data with no page the user may read: a notification and the menu again, no game screen in the period", function(flow)
    local client, server = flow.client, flow.server
    log_in(flow)
    client.session:join_game(mocks.GAME_ID)
    frame(server)
    frame(client)
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "Successfully logged in as adam",
        "Nothing to show: no page you may see"
    })
    test.assert_eq(client.data.game.page, nil)
    test.assert_deep_eq(client.data.tokens.T.owners, {
        "adam"
    }, "what the user reads is in")
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read:pages",
        "read:tokens"
    })
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry"
    })
    test.assert_eq(flow.client_connection:get_out_channel():getCount(), 0, "no asset request: the game is not entered")
end, function()
    return connect_the_sides(function(data)
        data.groups.spectator = {
            title = "Spectator",
            permissions = {
                "read:pages",
                "read:tokens"
            }
        }
        data.players.adam.group = "spectator"
    end)
end)

flow_case("back from the game: the menu is shown again, the game screen dies with its panels, newest first", function(flow)
    local client = flow.client
    local game_screen = client.screen_manager:get_screen() --[[@as GameScreen]]
    ---@type Input[]
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
        "GameScreen:release(destroy)"
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
        test.assert_false(lifetime.alive(input), "the inputs died with the panels' control tree")
    end
    test.assert_deep_eq(lifetime.dependents(game_screen), {}, "a dead anchor holds nothing")
end)

flow_case("the options: one screen per menu, a way back per visit, both the menu's", function(flow)
    local client = flow.client
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
end)

flow_case("the assets workspace from the game: under the period, its way back its own; back destroys it with its usage, details and list, and shows the game again", function(flow)
    local client, server = flow.client, flow.server
    local game_screen = assert(client.screen_manager:get_screen())
    local game_entry = client.backstack_manager:get_top()

    client.session:open_assets_workspace()
    local workspace = client.screen_manager:get_screen() --[[@as AssetsWorkspaceScreen]]
    test.assert_eq(get_class_name_of(workspace), "AssetsWorkspaceScreen")
    test.assert_eq(game_screen:get_control():get_parent(), nil, "the game screen is hidden meanwhile")
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GameScreen",
        "AssetsWorkspaceScreen"
    })
    local workspace_dependents = lifetime.dependents(workspace)
    test.assert_deep_eq(class_names_but_hooks(workspace_dependents), {
        "BackstackEntry"
    }, "the list, the details and the usage are the control tree's")
    test.assert_eq(client.backstack_manager:get_top(), workspace_dependents[#workspace_dependents])
    test.assert_deep_eq(workspace:get_shown_entries(), {}, "nothing before the server answers")
    frame(server)
    frame(client)
    test.assert_deep_eq(workspace:get_shown_entries(), {
        {
            path = "token",
            type = "directory"
        },
        {
            path = "world",
            type = "directory"
        }
    })
    test.assert_true(workspace:is_writable())

    local log = {}
    with_release_log(log, function()
        client.backstack_manager:back()
    end)
    test.assert_deep_eq(log, {
        "AssetsWorkspaceScreen:release(destroy)",
        "AssetUsageList:release(destroy)",
        "AssetDetails:release(destroy)",
        "PreviewArea:release(destroy)",
        "AssetList:release(destroy)"
    }, "the screen's tree newest first: the usage, the details with their preview, then the list")
    test.assert_false(lifetime.alive(workspace))
    test.assert_eq(client.screen_manager:get_screen(), game_screen)
    test.assert_eq(client.backstack_manager:get_top(), game_entry)
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(client.session._assets_workspace_screen, nil)
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GameScreen"
    })
end)

flow_case("the assets workspace from the game dies with the period on a disconnect, before the game screen", function(flow)
    local client, client_connection = flow.client, flow.client_connection
    local game_screen = assert(client.screen_manager:get_screen())
    client.session:open_assets_workspace()
    local workspace = client.screen_manager:get_screen()
    test.assert_eq(get_class_name_of(workspace), "AssetsWorkspaceScreen")
    test.assert_eq(game_screen:get_control():get_parent(), nil, "the game screen is hidden")

    local log = {}
    with_release_log(log, function()
        app = client
        client.connection_manager:remove(client_connection)
    end)
    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "AssetsWorkspaceScreen:release(anchor)",
        "AssetUsageList:release(destroy)",
        "AssetDetails:release(destroy)",
        "PreviewArea:release(destroy)",
        "AssetList:release(destroy)",
        "GameScreen:release(anchor)",
        "UserMenuScreen:release(anchor)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "CreateGameRp:release(anchor)",
        "ListGamesRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "CreateAccountRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(workspace))
    test.assert_false(lifetime.alive(game_screen))
    test.assert_deep_eq(client.root:get_children(), {}, "the workspace hid itself")
    test.assert_eq(client.screen_manager:get_screen(), nil)
end)

flow_case("the shown page changed to one the player may not read: the workspace over the game dies, then the game screen, and the menu is shown", function(flow)
    local client, server = flow.client, flow.server
    local game_screen = assert(client.screen_manager:get_screen())
    client.session:open_assets_workspace()
    local workspace = assert(client.screen_manager:get_screen())
    frame(server)
    frame(client)

    local log = {}
    with_release_log(log, function()
        app = client
        mocks.deliver(flow.client_connection, "EntryChangedRp", {
            kind = "game",
            id = "game",
            entry = {
                page = "Nowhere"
            }
        })
    end)
    test.assert_deep_eq(log, {
        "AssetsWorkspaceScreen:release(destroy)",
        "AssetUsageList:release(destroy)",
        "AssetDetails:release(destroy)",
        "PreviewArea:release(destroy)",
        "AssetList:release(destroy)",
        "GameScreen:release(destroy)"
    }, "the workspace first, which would show the dead game screen again on its way back")
    test.assert_false(lifetime.alive(workspace))
    test.assert_false(lifetime.alive(game_screen))
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_eq(notifications.messages[#notifications.messages], "Nothing to show: no page you may see")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry"
    })
    test.assert_deep_eq(client.root:get_children(), {
        client.screen_manager:get_screen():get_control()
    }, "only the menu is on the root")
    test.assert_deep_eq(mocks.sent(flow.client_connection)[1].body, {}, "the push acknowledged, which the server, who did not send it, is not given")
end)

flow_case("logout: the period dies with the menu, the options and the back entries; the login screen is the session's", function(flow)
    local client, server = flow.client, flow.server
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
        "ListGamesRp",
        "CreateGameRp",
        "UpdateTokenRp",
        "TokenChangedRp",
        "CreateTokenRp",
        "DeleteTokenRp",
        "TokenCreatedRp",
        "TokenDeletedRp",
        "UpdateEntryRp",
        "EntryChangedRp",
        "CreateEntryRp",
        "DeleteEntryRp",
        "EntryCreatedRp",
        "EntryDeletedRp",
        "GrantsChangedRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "ListAssetsRp",
        "CreateAssetFolderRp",
        "RenameAssetRp",
        "DeleteAssetRp",
        "hook",
        "LoginScreen"
    }, "the dead period left the session; the login screen is the session's until the next login")
    test.assert_eq(get_class_name_of(client.backstack_manager:get_top()), "BackstackEntry")
    client.backstack_manager:back()
    test.assert_true(quit_requested, "only the client's own quit entry is left")
end)

flow_case("logging in again from the login screen: the screen dies at the login and its fields let go of the pointer", function(flow)
    local client, server = flow.client, flow.server
    client.backstack_manager:back()
    client.backstack_manager:back()
    frame(server)
    frame(client)
    local login_screen = client.screen_manager:get_screen() --[[@as LoginScreen]]
    test.assert_eq(get_class_name_of(login_screen), "LoginScreen")

    -- the fields in a function of their own: no local of this case may hold
    -- them when the collector runs below
    local function fill_in_the_fields()
        ---@diagnostic disable-next-line: invisible
        local login_input, password_input = login_screen._login_input._input, login_screen._password_input._input
        click(client, login_input)
        client.text_event_manager:text_input("adam")
        click(client, password_input)
        client.text_event_manager:text_input("krause")
        test.assert_true(password_input:is_focused())
        return password_input:get_button()
    end
    local password_button = fill_in_the_fields()
    test.assert_true(password_button:is_hovered(), "the pointer rests on the password field")
    local log = {}
    with_release_log(log, function()
        client.text_event_manager:key_pressed("return")
        frame(server)
        frame(client)
    end)
    test.assert_deep_eq(log, {
        "LoginScreen:release(destroy)"
    }, "logged in: the login screen is over, destroyed rather than left to the collector")
    test.assert_false(lifetime.alive(login_screen))
    test.assert_false(password_button:is_hovered(), "a hidden field is no longer under the pointer")
    test.assert_deep_eq(class_names(lifetime.dependents(client.session)), {
        "Login",
        "GameDataRp",
        "ListGamesRp",
        "CreateGameRp",
        "UpdateTokenRp",
        "TokenChangedRp",
        "CreateTokenRp",
        "DeleteTokenRp",
        "TokenCreatedRp",
        "TokenDeletedRp",
        "UpdateEntryRp",
        "EntryChangedRp",
        "CreateEntryRp",
        "DeleteEntryRp",
        "EntryCreatedRp",
        "EntryDeletedRp",
        "GrantsChangedRp",
        "UploadAssetRp",
        "DownloadAssetRp",
        "DownloadMissingAssetsRp",
        "ListAssetsRp",
        "CreateAssetFolderRp",
        "RenameAssetRp",
        "DeleteAssetRp",
        "hook",
        "token"
    }, "the dead login screen left the session")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    client.session:join_game(mocks.GAME_ID)
    load_the_game(flow)

    -- under `love . test` their release runs while LÖVE frees their controls'
    -- transforms in the same collection
    collectgarbage("collect")
    test.assert_deep_eq(destroy_errors, {}, "no destructor touched a freed LÖVE object")
    move(client, 0, 0)
end)

flow_case("a button destroyed by its own click (the token panel's Cancel) lets go of the pointer", function(flow)
    local client = flow.client
    local game_screen = client.screen_manager:get_screen() --[[@as GameScreen]]
    local token_panel = game_screen:get_token_panel()
    game_screen:select_panel(token_panel)
    ---@diagnostic disable-next-line: invisible
    local cancel = token_panel._cancel_button --[[@as TextButton]]
    click(client, cancel)
    test.assert_false(lifetime.alive(cancel), "the cancel rebuilt the panel's fields and buttons")
    ---@diagnostic disable-next-line: invisible
    local new_cancel = token_panel._cancel_button --[[@as TextButton]]
    test.assert_false(new_cancel:is_hovered())
    local min_x, min_y, max_x, max_y = new_cancel:get_global_aabb():get_bounds()
    move(client, (min_x + max_x) * 0.5 + 1, (min_y + max_y) * 0.5)
    test.assert_true(new_cancel:is_hovered(), "the new button is under the pointer")
    move(client, 0, 0)
    test.assert_false(new_cancel:is_hovered())
end)

flow_case("disconnect: one cascade per side, the connection first, then the session's tree newest first", function(flow)
    local client, server, client_connection, server_connection, sessions = flow.client, flow.server, flow.client_connection, flow.server_connection, flow.sessions
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
        "UserMenuScreen:release(anchor)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "CreateGameRp:release(anchor)",
        "ListGamesRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "CreateAccountRp:release(anchor)",
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
        "CreateGameRp:release(anchor)",
        "ListGamesRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "CreateAccountRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(server_session))
    test.assert_eq(sessions[server_connection], nil)
end)

flow_case("quit: remove_all tears every connection down in order, as love.quit does before the state closes", function(flow)
    local client, server, client_connection, server_connection = flow.client, flow.server, flow.client_connection, flow.server_connection
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
        "CreateGameRp:release(anchor)",
        "ListGamesRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "CreateAccountRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)",
        "Connection:release(destroy)",
        "GameScreen:release(anchor)",
        "UserMenuScreen:release(anchor)",
        "DownloadMissingAssetsRp:release(anchor)",
        "DownloadAssetRp:release(anchor)",
        "UploadAssetRp:release(anchor)",
        "CreateGameRp:release(anchor)",
        "ListGamesRp:release(anchor)",
        "GameDataRp:release(anchor)",
        "CreateAccountRp:release(anchor)",
        "LogoutRp:release(anchor)",
        "LoginRp:release(anchor)"
    })
    test.assert_false(lifetime.alive(client_connection))
    test.assert_false(lifetime.alive(server_connection))
    test.assert_eq(next(client.connection_manager:get_connections()), nil)
    test.assert_eq(next(server.connection_manager:get_connections()), nil)
end)

---@param flow TestFlow Logged in, on the menu
---@return GamesScreen
local function show_the_games(flow)
    local client, server = flow.client, flow.server
    app = client
    client.session:show_games()
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen", "nothing before the listing is in")
    frame(server)
    frame(client)
    local screen = client.screen_manager:get_screen() --[[@as GamesScreen]]
    test.assert_eq(get_class_name_of(screen), "GamesScreen")
    return screen
end

---@return TestFlow
local function log_in_to_the_menu()
    local flow = connect_the_sides()
    log_in(flow)
    return flow
end

flow_case("the games: listed under the period with a way back of their own; back shows the menu and destroys them", function(flow)
    local client = flow.client
    local menu = client.screen_manager:get_screen()
    local logout_entry = client.backstack_manager:get_top()
    local games = show_the_games(flow)
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GamesScreen"
    })
    local games_dependents = lifetime.dependents(games)
    test.assert_deep_eq(class_names_but_hooks(games_dependents), {
        "BackstackEntry"
    })
    test.assert_eq(client.backstack_manager:get_top(), games_dependents[#games_dependents])

    local log = {}
    with_release_log(log, function()
        client.backstack_manager:back()
    end)
    test.assert_deep_eq(log, {
        "GamesScreen:release(destroy)"
    })
    test.assert_eq(client.screen_manager:get_screen(), menu)
    test.assert_eq(client.backstack_manager:get_top(), logout_entry)
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(client.session._games_screen, nil)
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry"
    })
end, log_in_to_the_menu)

flow_case("a listing asked for again replaces the games screen; one that answers after the logout is ignored", function(flow)
    local client, server = flow.client, flow.server
    local first = show_the_games(flow)
    local log = {}
    with_release_log(log, function()
        client.session:show_games()
        frame(server)
        frame(client)
    end)
    test.assert_deep_eq(log, {
        "GamesScreen:release(destroy)"
    }, "the first screen, once the second is shown")
    test.assert_false(lifetime.alive(first))
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GamesScreen"
    })

    client.backstack_manager:back()
    client.session:show_games()
    client.session:logout()
    frame(server)
    frame(client)
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "LoginScreen", "the listing came after the logout")
end, log_in_to_the_menu)

flow_case("the new game over the games: back shows the games again; a join destroys both, so the game's entry is right above the logout's", function(flow)
    local client = flow.client
    local logout_entry = client.backstack_manager:get_top()
    local games = show_the_games(flow)
    client.session:show_new_game()
    local new_game = client.screen_manager:get_screen()
    test.assert_eq(get_class_name_of(new_game), "NewGameScreen")
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GamesScreen",
        "NewGameScreen"
    })
    local log = {}
    with_release_log(log, function()
        client.backstack_manager:back()
    end)
    test.assert_deep_eq(log, {
        "NewGameScreen:release(destroy)"
    })
    test.assert_eq(client.screen_manager:get_screen(), games)

    client.session:show_new_game()
    new_game = client.screen_manager:get_screen()
    log = {}
    with_release_log(log, function()
        client.session:join_game(mocks.GAME_ID)
    end)
    test.assert_deep_eq(log, {
        "NewGameScreen:release(destroy)",
        "GamesScreen:release(destroy)"
    })
    test.assert_false(lifetime.alive(games))
    test.assert_false(lifetime.alive(new_game))
    load_the_game(flow)
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(class_names(lifetime.dependents(client.session._period)), {
        "UserMenuScreen",
        "BackstackEntry",
        "GameScreen"
    })
    client.backstack_manager:back()
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    test.assert_eq(client.backstack_manager:get_top(), logout_entry)
end, log_in_to_the_menu)

flow_case("a game that is not there: the refusal is notified and the menu shown", function(flow)
    local client, server = flow.client, flow.server
    show_the_games(flow)
    client.session:join_game("gone")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen")
    frame(server)
    frame(client)
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_eq(notifications.messages[#notifications.messages], "No such game")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    test.assert_eq(client.data, nil)
end, log_in_to_the_menu)

flow_case("a new game: made from the template on the server, its creator the master and the owner of its token, and joined", function(flow)
    local client, server = flow.client, flow.server
    show_the_games(flow)
    client.session:show_new_game()
    client.session:create_game("The Shire!")
    frame(server)
    frame(client)
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen", "created: the game is joined")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(client.session._games_screen, nil)
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(client.session._new_game_screen, nil)
    frame(server)
    frame(client)
    frame(server)
    frame(client)
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "GameScreen")
    local data = assert(client.data)
    test.assert_eq(data.name, "The Shire!")
    test.assert_deep_eq(data.players, {
        adam = {
            group = "master"
        }
    })
    test.assert_deep_eq(data.tokens.Hero.owners, {
        "adam"
    })
    test.assert_eq(assert(client.asset_manager:get_store()):get_root(), "c/games/the-shire")
    test.assert_eq(love.filesystem.read("c/games/the-shire/assets/world/table.png"), "TABLE", "the template's assets downloaded")
    local saved = table.from_string(assert(love.filesystem.read("s/games/the-shire/save.lua"))) --[[@as GameData]]
    test.assert_eq(saved.name, "The Shire!")
    test.assert_eq(love.filesystem.read("s/games/the-shire/assets/token/default.png"), "D")

    client.backstack_manager:back()
    app = server
    local listing = mocks.request(flow.server_connection, "ListGamesRp", {}) --[[@as ListGamesResponse]]
    test.assert_deep_eq(listing.games, {
        {
            id = "g",
            name = "G",
            member = true
        },
        {
            id = "the-shire",
            name = "The Shire!",
            member = true
        }
    })

    show_the_games(flow)
    client.session:create_game("the shire")
    frame(server)
    frame(client)
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_eq(notifications.messages[#notifications.messages], "A game named \"The Shire!\" exists already")
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "GamesScreen", "a refusal joins nothing")
end, log_in_to_the_menu)

flow_case("sign up: the screen is the session's with a way back; the account is made and the client logged in, both screens destroyed at the login", function(flow)
    local client, server = flow.client, flow.server
    local login_screen = client.screen_manager:get_screen()
    client.session:show_sign_up()
    local sign_up = client.screen_manager:get_screen()
    test.assert_eq(get_class_name_of(sign_up), "SignUpScreen")
    local dependents = class_names(lifetime.dependents(client.session))
    test.assert_eq(dependents[#dependents], "SignUpScreen", "anchored to the session, after the login screen")
    local log = {}
    with_release_log(log, function()
        client.backstack_manager:back()
    end)
    test.assert_deep_eq(log, {
        "SignUpScreen:release(destroy)"
    })
    test.assert_eq(client.screen_manager:get_screen(), login_screen)

    client.session:show_sign_up()
    sign_up = client.screen_manager:get_screen()
    log = {}
    with_release_log(log, function()
        client.session:sign_up("frodo", "Frodo", "ring")
        frame(server)
        frame(client)
        test.assert_deep_eq(log, {}, "the account is made: the login is asked for")
        frame(server)
        frame(client)
    end)
    test.assert_deep_eq(log, {
        "LoginScreen:release(destroy)",
        "SignUpScreen:release(destroy)"
    })
    test.assert_true(client.session:is_logged_in())
    test.assert_eq(client.session:get_user(), "frodo")
    test.assert_false(lifetime.alive(sign_up))
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    local notifications = client.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "Account created",
        "Successfully logged in as frodo"
    })
    local accounts = table.from_string(assert(love.filesystem.read("s/accounts.lua"))) --[[@as table<string, AccountData>]]
    test.assert_eq(accounts.frodo.name, "Frodo")
    test.assert_true(accounts.adam ~= nil)
    test.assert_eq(get_class_name_of(client.backstack_manager:get_top()), "BackstackEntry")
    client.backstack_manager:back()
    frame(server)
    frame(client)
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "LoginScreen", "the way back from the menu logs out")
end, connect_the_sides)

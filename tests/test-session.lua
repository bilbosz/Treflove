local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")

-- The session's ownership tree (game/session.tlt, app/client.tlt,
-- app/server.tlt; docs/lifetime.md, "Ownership"), driven the way
-- lua-lifetime's trial/treflove/harness.lua drives it: a client app and a
-- server app (Treflove's app mock with the real ConnectionManager,
-- AssetManager, ScreenManager and, on the client, BackstackManager) whose
-- connections are mock channels back to back; the real Session, Login,
-- LoginRp, LogoutRp, GameDataRp, the asset procedures and the connection
-- callbacks of Client:load and Server:load.
--
-- The screen layer is a test double. The real screens cannot be constructed
-- under plain LuaJIT with the mocks: a MenuScreen (UserMenuScreen,
-- LoginScreen) builds its Logo in its constructor, which calls
-- love.graphics.newImage("icon.png") and newShader, and its Text entries
-- need love.graphics fonts and text objects; the WaitingScreen
-- (ConnectingScreen) builds a Logo too; and laying out the menu
-- (`_create_entries`, `_center_layout`) needs real transforms from
-- love.math, which mocks.ensure_love_math replaces by one that ignores
-- every operation. Under `love . test` there is no window either, so
-- love.graphics cannot make images. The doubles stand where the five screen
-- modules (screens.user-menu-screen, login.login-screen,
-- screens.waiting-screen, screens.connecting-screen, game.game-screen)
-- are required, and only while game.session, game.game-data-rp, app.client
-- and app.server are loaded for this file; package.loaded is restored
-- afterwards, so no other test sees them. Each double logs `show`, `hide`
-- and its release, so the logs pin that a screen is replaced before it dies
-- (docs/lifetime.md, "Screens": the real ScreenManager calls `hide` on
-- the screen it replaces, which raises on a tombstone).
--
-- Every log is compared whole. A line starting with `>` names the statement
-- that runs next, so each death sits under the statement that caused it.
-- Each class's release is wrapped to log `Class:release(reason)`, or
-- `Class destroyed (reason)` for a class that has none (Session, Login); a
-- call made inside a logged method is indented, which shows each
-- procedure's stop() reaching its connection. The expected sequences were
-- written from lua-lifetime docs/02-semantics.md, "Cascading death",
-- before the first run: a dying object's own release first, with every
-- dependent alive, then its dependents most recently attached first, each
-- by the same rule, a dead one skipped.

local log = {}
local depth = 0

---@param line string
local function trace(line)
    table.insert(log, string.rep("  ", depth) .. line)
end

-- The screen doubles.
local TestScreen = class("TestScreen")

function TestScreen:show()
    trace("show " .. get_class_name_of(self))
end

function TestScreen:hide()
    trace("hide " .. get_class_name_of(self))
end

function TestScreen:on_resize()
end

-- When set, the user menu double's join_game does what the real one does
-- (screens/user-menu-screen.tlt): the session's join_game.
local forward_join_game = false

local TestUserMenuScreen = class("TestUserMenuScreen", TestScreen)

---@param session Session
function TestUserMenuScreen:init(session)
    self._session = session
end

function TestUserMenuScreen:join_game()
    trace("TestUserMenuScreen:join_game()")
    if forward_join_game then
        self._session:join_game()
    end
end

-- The depth of the back stack when the menu dies pins whether the logout
-- entry, anchored to the same period after it, went first.
function TestUserMenuScreen:release()
    trace("back stack depth " .. #app.backstack_manager._stack)
end

local TestLoginScreen = class("TestLoginScreen", TestScreen)

---@param login Login
function TestLoginScreen:init(login)
    self._login = login
end

function TestLoginScreen:release()
end

local TestWaitingScreen = class("TestWaitingScreen", TestScreen)

---@param message string
function TestWaitingScreen:init(message)
    self._message = message
end

local TestConnectingScreen = class("TestConnectingScreen", TestScreen)

local TestGameScreen = class("TestGameScreen", TestScreen)

---@param data GameScreenData
function TestGameScreen:init(data)
    self._data = data
end

function TestGameScreen:release()
end

-- Load the session slice against the doubles, then put package.loaded back.
local DOUBLES = {
    ["screens.user-menu-screen"] = TestUserMenuScreen,
    ["login.login-screen"] = TestLoginScreen,
    ["screens.waiting-screen"] = TestWaitingScreen,
    ["screens.connecting-screen"] = TestConnectingScreen,
    ["game.game-screen"] = TestGameScreen
}
local LOADED_WITH_DOUBLES = {"game.game-data-rp", "game.session", "app.client", "app.server"}

local function load_with_doubles()
    local saved = {}
    for name, double in pairs(DOUBLES) do
        saved[name] = package.loaded[name]
        package.loaded[name] = double
    end
    for _, name in ipairs(LOADED_WITH_DOUBLES) do
        saved[name] = package.loaded[name]
        package.loaded[name] = nil
    end
    local modules = {}
    for _, name in ipairs(LOADED_WITH_DOUBLES) do
        modules[name] = require(name)
    end
    for name, value in pairs(saved) do
        package.loaded[name] = value
    end
    for _, name in ipairs(LOADED_WITH_DOUBLES) do
        if saved[name] == nil then
            package.loaded[name] = nil
        end
    end
    return modules
end

local loaded = load_with_doubles()
local Session = loaded["game.session"]
local GameDataRp = loaded["game.game-data-rp"]
local Client = loaded["app.client"]
local Server = loaded["app.server"]
local AssetManager = require("data.asset-manager")
local BackstackManager = require("utils.backstack-manager")
local Connection = require("networking.connection")
local ConnectionManager = require("networking.connection-manager")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local Login = require("login.login")
local LoginRp = require("login.login-rp")
local LogoutRp = require("login.logout-rp")
local ScreenManager = require("screens.screen-manager")
local UploadAssetRp = require("data.upload-asset-rp")
local Utils = require("utils.utils")

-- The instrumentation: wrapped while a case runs, restored after it. A
-- class table reads and writes its merged method index (utils/class.tlt),
-- so plain indexing patches every instance.
local INSTRUMENTED = {
    {Connection, "Connection"},
    {Session, "Session"},
    {Login, "Login"},
    {LoginRp, "LoginRp"},
    {LogoutRp, "LogoutRp"},
    {GameDataRp, "GameDataRp"},
    {UploadAssetRp, "UploadAssetRp"},
    {DownloadAssetRp, "DownloadAssetRp"},
    {DownloadMissingAssetsRp, "DownloadMissingAssetsRp"},
    {TestUserMenuScreen, "TestUserMenuScreen"},
    {TestLoginScreen, "TestLoginScreen"},
    {TestGameScreen, "TestGameScreen"}
}

local originals = {}

---@param f function
local function deeper(f, ...)
    depth = depth + 1
    local result = {pcall(f, ...)}
    depth = depth - 1
    if not result[1] then
        error(result[2], 0)
    end
    return unpack(result, 2)
end

local function instrument()
    for _, entry in ipairs(INSTRUMENTED) do
        local cls, name = entry[1], entry[2]
        local release = cls.release
        table.insert(originals, {cls, "release", release})
        cls.release = function(self, reason)
            if release then
                trace(name .. ":release(" .. tostring(reason) .. ")")
                return deeper(release, self, reason)
            end
            trace(name .. " destroyed (" .. tostring(reason) .. ")")
        end
    end
    local unregister = Connection.unregister_request_handler
    table.insert(originals, {Connection, "unregister_request_handler", unregister})
    Connection.unregister_request_handler = function(self, id)
        trace("Connection:unregister_request_handler(" .. id .. ")")
        return deeper(unregister, self, id)
    end
end

local function restore()
    for i = #originals, 1, -1 do
        local cls, method, value = originals[i][1], originals[i][2], originals[i][3]
        cls[method] = value
    end
    originals = {}
end

-- The file system the asset code touches: the server mounts its `server`
-- directory (an empty one here), and the client already has every asset,
-- so its missing-asset list comes out empty. Swapped in while a case runs
-- (the real love.filesystem under `love . test`), restored after it.
local FAKE_FILESYSTEM = {
    getInfo = function(path)
        if path == "server" then
            return {
                type = "directory"
            }
        elseif string.sub(path, 1, 2) == "c/" then
            return {
                type = "file"
            }
        end
        return nil
    end,
    createDirectory = function()
        return true
    end,
    getDirectoryItems = function()
        return {}
    end,
    remove = function()
        return true
    end
}

local saved_filesystem

local function install_filesystem()
    saved_filesystem = {
        had_module = love.filesystem ~= nil
    }
    love.filesystem = love.filesystem or {}
    for name, f in pairs(FAKE_FILESYSTEM) do
        saved_filesystem[name] = love.filesystem[name]
        love.filesystem[name] = f
    end
end

local function restore_filesystem()
    if not saved_filesystem.had_module then
        love.filesystem = nil
        return
    end
    for name in pairs(FAKE_FILESYSTEM) do
        love.filesystem[name] = saved_filesystem[name]
    end
end

-- The persisted state the server serves: one player and a page with one
-- token. `auth` is what LoginRp stores for adam/krause, computed with the
-- same love.data and love.math the login uses (login/login.tlt and
-- login/login-rp.tlt hash the client's hash again on the server side).
local function make_game_state()
    app = {
        is_client = true,
        is_server = false
    }
    local client_auth = Utils.hash("adam" .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. "krause")
    app = {
        is_client = false,
        is_server = true
    }
    local auth = Utils.hash("adam" .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. client_auth)
    return {
        game = {
            page = "map"
        },
        pages = {
            map = {
                name = "map",
                image = "map.png",
                tokens = {"knight"}
            }
        },
        tokens = {
            knight = {
                name = "knight",
                avatar = "knight.png"
            }
        },
        players = {
            adam = {
                name = "adam",
                auth = auth,
                group = "master"
            }
        }
    }
end

-- The connector's thread and sockets are outside the test: connections are
-- added by hand (`connect`).
local function stub_connector(connection_manager)
    connection_manager._connector = {
        start = function()
        end,
        remove_thread = function()
        end
    }
end

-- A client app: the app mock, the managers the session uses, Client:load.
local function new_client()
    local client = mocks.install_app({
        is_client = true,
        is_server = false
    })
    client.text_event_manager = {
        set_text_input = function()
        end
    }
    client.notification_manager = {
        notify = function(_, text)
            trace("notify: " .. text)
        end
    }
    client.quit = function()
        trace("app:quit()")
    end
    client.screen_manager = ScreenManager()
    client.backstack_manager = BackstackManager()
    client.connection_manager = ConnectionManager("localhost", "8080")
    stub_connector(client.connection_manager)
    client.asset_manager = AssetManager()
    trace("> client: Client.load")
    Client.load(client)
    return client
end

-- A server app: the app mock, the managers the session uses, Server:load
-- (without reading save.lua: the state is make_game_state's).
local function new_server()
    local data = make_game_state()
    local server = mocks.install_app({
        is_client = false,
        is_server = true
    })
    server.data = data
    server._sessions = {}
    server._load_data = function()
    end
    server.connection_manager = ConnectionManager("localhost", "8080")
    stub_connector(server.connection_manager)
    server.asset_manager = AssetManager()
    trace("> server: Server.load")
    Server.load(server)
    return server
end

-- The server and the client each add their end of a pair of mock
-- channels, back to back, as the connector would. The client's session
-- sends the login request (game/session.tlt).
local function connect(client, server)
    trace("> connect")
    local client_to_server = mocks.make_channel()
    local server_to_client = mocks.make_channel()
    app = server
    server.connection_manager:add_connection(client_to_server, mocks.make_thread(), server_to_client, mocks.make_thread())
    app = client
    client.connection_manager:add_connection(server_to_client, mocks.make_thread(), client_to_server, mocks.make_thread())
    return client.connection_manager._by_in_channel[server_to_client], server.connection_manager._by_in_channel[client_to_server]
end

-- One frame of `side`: the update event, which runs the connections'
-- on_update (requests answered, responses received).
local function frame(name, side)
    trace("> " .. name .. " frame")
    app = side
    side.update_event:trigger(0.016)
end

local function disconnect(name, side, connection)
    trace("> " .. name .. ": connection_manager:remove(connection)")
    app = side
    side.connection_manager:remove(connection)
end

local function count_entries(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function count_asset_entries(asset_manager)
    return count_entries(asset_manager._upload_asset_rp) + count_entries(asset_manager._download_asset_rp) + count_entries(asset_manager._download_missing_assets_rp)
end

-- Compare the log with `expected` line by line; on a mismatch, report the
-- first difference and the whole log.
local function assert_log(expected)
    for i = 1, math.max(#log, #expected) do
        if log[i] ~= expected[i] then
            local lines = {}
            for j, line in ipairs(log) do
                table.insert(lines, string.format("  %3d %s", j, line))
            end
            error(string.format("log differs at line %d:\n  expected: %s\n  actual:   %s\nactual log:\n%s", i, tostring(expected[i]), tostring(log[i]), table.concat(lines, "\n")), 2)
        end
    end
end

local function concat(...)
    local out = {}
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if type(part) == "string" then
            table.insert(out, part)
        else
            for _, line in ipairs(part) do
                table.insert(out, line)
            end
        end
    end
    return out
end

-- A procedure's release and the unregistering its stop() makes on the
-- dying connection.
local function rp(name)
    return {name .. ":release(anchor)", "  Connection:unregister_request_handler(" .. name .. ")"}
end

-- Below a session, in the order of "Cascading death": Session.init
-- attached Login, then GameDataRp, then AssetManager:register_session the
-- upload, download and download-missing procedures and its hook (which
-- logs nothing); Login.init attached LoginRp, then LogoutRp. Most recently
-- attached first: the asset procedures newest first, GameDataRp (and what
-- it owns: `game_screen`, the game screen it showed, if any), then Login
-- (its own release first, it has none; then LogoutRp, LoginRp).
local function session_procedures(game_screen)
    return concat(rp("DownloadMissingAssetsRp"), rp("DownloadAssetRp"), rp("UploadAssetRp"), rp("GameDataRp"), game_screen or {}, "Login destroyed (anchor)", rp("LogoutRp"), rp("LoginRp"))
end

-- Run `fn` with the fakes and the instrumentation in place, and the
-- destroyerror handler logging; undo all of it however `fn` ends. Two
-- collections at the end must log nothing.
local function run(fn)
    -- What an earlier case left behind (when it failed half-way) is
    -- finalized now, outside this case's log.
    collectgarbage("collect")
    collectgarbage("collect")
    mocks.ensure_love_login()
    log = {}
    depth = 0
    forward_join_game = false
    install_filesystem()
    instrument()
    local previous_destroyerror = rawget(_G, "destroyerror")
    rawset(_G, "destroyerror", function(_, err)
        trace("destroyerror: " .. tostring(err))
    end)
    local ok, err = pcall(fn)
    if ok then
        trace("> collectgarbage twice")
        collectgarbage("collect")
        collectgarbage("collect")
    end
    rawset(_G, "destroyerror", previous_destroyerror)
    restore()
    restore_filesystem()
    if not ok then
        error(err, 0)
    end
end

-- The client's log up to a logged-in session: the login response shows
-- the user menu, and the session's on_login calls its join_game.
local LOGGED_IN = {"> client: Client.load", "show TestConnectingScreen", "> server: Server.load", "> connect", "> server frame", "> client frame", "notify: Successfully logged in as adam", "hide TestConnectingScreen", "show TestUserMenuScreen", "TestUserMenuScreen:join_game()"}

test.suite("Session")

test.case("removing a logged-in client's connection tears its session down in ownership order", function()
    run(function()
        local client = new_client()
        local server = new_server()
        forward_join_game = true
        local client_connection, server_connection = connect(client, server)
        frame("server", server)
        frame("client", client)
        frame("server", server)
        frame("client", client)
        frame("server", server)
        frame("client", client)
        local session = client.session
        local login = session._login
        local period = session._period
        local menu = session._user_menu_screen
        local game_screen = client.screen_manager:get_screen()
        local channel = client_connection:get_in_channel()
        trace("back stack depth " .. #client.backstack_manager._stack)
        disconnect("client", client, client_connection)
        trace("alive: connection " .. tostring(lifetime.alive(client_connection)) .. ", session " .. tostring(lifetime.alive(session)) .. ", login " .. tostring(lifetime.alive(login)) .. ", period " .. tostring(lifetime.alive(period)) .. ", menu " .. tostring(lifetime.alive(menu)) .. ", game screen " .. tostring(lifetime.alive(game_screen)))
        trace("app.session " .. tostring(client.session) .. ", app.data " .. tostring(client.data) .. ", back stack depth " .. #client.backstack_manager._stack)
        trace("in channel released " .. tostring(channel._released) .. ", connections left " .. count_entries(client.connection_manager:get_connections()) .. ", asset entries left " .. count_asset_entries(client.asset_manager))
        disconnect("server", server, server_connection)
    end)
    -- The client (written before the first run): the disconnect callback
    -- shows the connecting screen, replacing the game screen; then one
    -- lifetime.destroy(connection): the connection's release ("destroy"),
    -- its one dependent the session ("anchor"), whose dependents newest
    -- first are the period (a token, no body: its back entry, attached
    -- last, leaves the stack through its hook, then the menu dies, seeing
    -- only the quit entry left), the asset procedures, GameDataRp with the
    -- game screen it owns, and Login with its procedures.
    assert_log(concat(LOGGED_IN, "hide TestUserMenuScreen", "show TestWaitingScreen", "> server frame", "> client frame", "hide TestWaitingScreen", "show TestWaitingScreen", "> server frame", "> client frame", "hide TestWaitingScreen", "show TestGameScreen", "back stack depth 2", "> client: connection_manager:remove(connection)", "hide TestGameScreen", "show TestConnectingScreen", "Connection:release(destroy)", "Session destroyed (anchor)", "TestUserMenuScreen:release(anchor)", "  back stack depth 1", session_procedures({"TestGameScreen:release(anchor)"}),
        "alive: connection false, session false, login false, period false, menu false, game screen false", "app.session nil, app.data nil, back stack depth 1", "in channel released true, connections left 0, asset entries left 0",
        -- The server's session has no period and no screens.
        "> server: connection_manager:remove(connection)", "Connection:release(destroy)", "Session destroyed (anchor)", session_procedures(), "> collectgarbage twice"))
end)

test.case("logging out shows the login screen, then destroys the period and what hangs on it", function()
    local session, period, menu
    run(function()
        local client = new_client()
        local server = new_server()
        local client_connection, server_connection = connect(client, server)
        frame("server", server)
        frame("client", client)
        session = client.session
        period = session._period
        menu = session._user_menu_screen
        trace("logged in " .. tostring(session:is_logged_in()) .. ", back stack depth " .. #client.backstack_manager._stack)
        trace("> client: backstack_manager:back()")
        client.backstack_manager:back()
        trace("back stack depth " .. #client.backstack_manager._stack)
        frame("server", server)
        frame("client", client)
        trace("logged in " .. tostring(session:is_logged_in()) .. ", period " .. tostring(session._period) .. ", period alive " .. tostring(lifetime.alive(period)) .. ", menu alive " .. tostring(lifetime.alive(menu)) .. ", shown " .. get_class_name_of(client.screen_manager:get_screen()))
        disconnect("client", client, client_connection)
        disconnect("server", server, server_connection)
    end)
    -- The back key destroys the logout entry (it leaves the stack) and runs
    -- it; the server answers the logout; the client's _on_logout shows the
    -- login screen first, replacing the menu, then destroys the period: the
    -- entry is dead already and skipped ("Explicit destruction": destroy of
    -- a dead object is a no-op), the menu dies seeing the quit entry alone.
    -- The disconnect then reaches the login screen first among the
    -- session's dependents (the newest), the dead period skipped.
    assert_log(concat(LOGGED_IN, "logged in true, back stack depth 2", "> client: backstack_manager:back()", "back stack depth 1", "> server frame", "> client frame", "hide TestUserMenuScreen", "show TestLoginScreen", "TestUserMenuScreen:release(anchor)", "  back stack depth 1", "logged in false, period nil, period alive false, menu alive false, shown TestLoginScreen", "> client: connection_manager:remove(connection)", "hide TestLoginScreen", "show TestConnectingScreen", "Connection:release(destroy)", "Session destroyed (anchor)",
        "TestLoginScreen:release(anchor)", session_procedures(), "> server: connection_manager:remove(connection)", "Connection:release(destroy)", "Session destroyed (anchor)", session_procedures(), "> collectgarbage twice"))
end)

test.case("removing a server connection destroys its session, and the asset entries go with it", function()
    run(function()
        local client = new_client()
        local server = new_server()
        local client_connection, server_connection = connect(client, server)
        frame("server", server)
        local session = server._sessions[server_connection]
        trace("sessions " .. count_entries(server._sessions) .. ", logged in " .. tostring(session:get_user()) .. ", asset entries " .. count_asset_entries(server.asset_manager))
        disconnect("server", server, server_connection)
        trace("sessions " .. count_entries(server._sessions) .. ", session alive " .. tostring(lifetime.alive(session)) .. ", asset entries " .. count_asset_entries(server.asset_manager))
        disconnect("client", client, client_connection)
    end)
    -- The server's disconnect callback only clears the entry; the cascade
    -- runs as on the client, without the period and the screens. The
    -- session's hook in AssetManager (attached after its procedures, so run
    -- before them) has emptied the per-session tables by the end. The
    -- client, never answered, is logged out and on the connecting screen.
    assert_log(concat("> client: Client.load", "show TestConnectingScreen", "> server: Server.load", "> connect", "> server frame", "sessions 1, logged in adam, asset entries 3", "> server: connection_manager:remove(connection)", "Connection:release(destroy)", "Session destroyed (anchor)", session_procedures(), "sessions 0, session alive false, asset entries 0", "> client: connection_manager:remove(connection)", "hide TestConnectingScreen", "show TestConnectingScreen", "Connection:release(destroy)", "Session destroyed (anchor)", session_procedures(), "> collectgarbage twice"))
end)

-- Drops every reference the server holds to its connection and session,
-- without destroying them, in a function of its own so that no stack slot
-- of the caller still refers to them (lua-lifetime docs/02-semantics.md,
-- "Reachability is the collector's").
local function forget(server, in_channel, out_channel)
    local manager = server.connection_manager
    for connection in pairs(manager._connections) do
        server._sessions[connection] = nil
        manager._connections[connection] = nil
    end
    manager._by_in_channel[in_channel] = nil
    manager._by_out_channel[out_channel] = nil
end

local function add_server_connection(server, in_channel, out_channel)
    app = server
    server.connection_manager:add_connection(in_channel, mocks.make_thread(), out_channel, mocks.make_thread())
end

test.case("a dropped session is collected with its connection, its procedures stopped", function()
    local in_channel, out_channel = mocks.make_channel(), mocks.make_channel()
    local server
    run(function()
        server = new_server()
        add_server_connection(server, in_channel, out_channel)
        trace("sessions " .. count_entries(server._sessions) .. ", asset entries " .. count_asset_entries(server.asset_manager))
        trace("> the server forgets the connection and its session, without destroy")
        forget(server, in_channel, out_channel)
        trace("> collectgarbage(\"collect\")")
        collectgarbage("collect")
        trace("> collectgarbage(\"collect\")")
        collectgarbage("collect")
        trace("asset entries " .. count_asset_entries(server.asset_manager) .. ", in channel released " .. tostring(in_channel._released))
    end)
    -- The connection, the session and everything under it are one cycle
    -- (each procedure refers to the connection, the session back to it).
    -- Within one collection an anchor is finalized before its dependents
    -- ("Reachability is the collector's"), so the first collection runs
    -- one cascade from the root: the connection "unreachable", everything
    -- below it "anchor", in the teardown's order, every stop() reaching
    -- the dying connection. The second collection clears the weak
    -- per-session tables of AssetManager.
    assert_log(concat("> server: Server.load", "sessions 1, asset entries 3", "> the server forgets the connection and its session, without destroy", "> collectgarbage(\"collect\")", "Connection:release(unreachable)", "Session destroyed (anchor)", session_procedures(), "> collectgarbage(\"collect\")", "asset entries 0, in channel released true", "> collectgarbage twice"))
end)

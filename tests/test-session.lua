local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local AssetManager = require("data.asset-manager")
local CreateAssetFolderRp = require("data.create-asset-folder-rp")
local DeleteAssetRp = require("data.delete-asset-rp")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local ListAssetsRp = require("data.list-assets-rp")
local RenameAssetRp = require("data.rename-asset-rp")
local UploadAssetRp = require("data.upload-asset-rp")
local CreateGameRp = require("game.create-game-rp")
local DeleteGameRp = require("game.delete-game-rp")
local GameDeletedRp = require("game.game-deleted-rp")
local GameDataRp = require("game.game-data-rp")
local ListGamesRp = require("game.list-games-rp")
local Session = require("game.session")
local TokenChangedRp = require("game.token-changed-rp")
local CreateTokenRp = require("game.create-token-rp")
local DeleteTokenRp = require("game.delete-token-rp")
local TokenCreatedRp = require("game.token-created-rp")
local TokenDeletedRp = require("game.token-deleted-rp")
local UpdateTokenRp = require("game.update-token-rp")
local CreateEntryRp = require("game.entry.create-entry-rp")
local DeleteEntryRp = require("game.entry.delete-entry-rp")
local EntryChangedRp = require("game.entry.entry-changed-rp")
local EntryCreatedRp = require("game.entry.entry-created-rp")
local EntryDeletedRp = require("game.entry.entry-deleted-rp")
local GrantsChangedRp = require("game.entry.grants-changed-rp")
local UpdateEntryRp = require("game.entry.update-entry-rp")
local CreateAccountRp = require("login.create-account-rp")
local LoginRp = require("login.login-rp")
local LogoutRp = require("login.logout-rp")
local Connection = require("networking.connection")
local Control = require("controls.control")
local ScreenManager = require("screens.screen-manager")
local BackstackManager = require("utils.backstack-manager")

---@return AppMock
---@return Connection
local function make_client()
    local app_mock = mocks.install_app()
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    app_mock.asset_manager = AssetManager()
    local connection = Connection(mocks.make_channel(), mocks.make_channel())
    return app_mock, connection
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
    DeleteGameRp = DeleteGameRp,
    GameDeletedRp = GameDeletedRp,
    UpdateTokenRp = UpdateTokenRp,
    TokenChangedRp = TokenChangedRp,
    CreateTokenRp = CreateTokenRp,
    DeleteTokenRp = DeleteTokenRp,
    TokenCreatedRp = TokenCreatedRp,
    TokenDeletedRp = TokenDeletedRp,
    UpdateEntryRp = UpdateEntryRp,
    EntryChangedRp = EntryChangedRp,
    CreateEntryRp = CreateEntryRp,
    DeleteEntryRp = DeleteEntryRp,
    EntryCreatedRp = EntryCreatedRp,
    EntryDeletedRp = EntryDeletedRp,
    GrantsChangedRp = GrantsChangedRp,
    UploadAssetRp = UploadAssetRp,
    DownloadAssetRp = DownloadAssetRp,
    DownloadMissingAssetsRp = DownloadMissingAssetsRp,
    ListAssetsRp = ListAssetsRp,
    CreateAssetFolderRp = CreateAssetFolderRp,
    RenameAssetRp = RenameAssetRp,
    DeleteAssetRp = DeleteAssetRp
}

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
    ---@type boolean, any
    local ok, err = pcall(fn)
    for name, cls in pairs(CLASSES) do
        cls.release = originals[name]
    end
    if not ok then
        error(err, 0)
    end
end

test.suite("Session")

test.case("a client session owns its login, the game procedures and the asset procedures, in creation order", function()
    local app_mock, connection = make_client()
    local session = Session(connection):attach_lifetime(connection)
    test.assert_eq(lifetime.format(lifetime.of(session)), "(" .. tostring(connection) .. ", reachable)")
    local dependents = lifetime.dependents(session)
    test.assert_eq(#dependents, 27,
                   "login, game data, games list, new game, the game deletion and its push, the token update and push, the token creation and deletion and their pushes, the entry procedures and the grants push, seven asset procedures and the asset manager's hook")
    test.assert_eq(get_class_name_of(dependents[1]), "Login")
    test.assert_eq(get_class_name_of(dependents[2]), "GameDataRp")
    test.assert_eq(get_class_name_of(dependents[3]), "ListGamesRp")
    test.assert_eq(get_class_name_of(dependents[4]), "CreateGameRp")
    test.assert_eq(get_class_name_of(dependents[5]), "DeleteGameRp")
    test.assert_eq(get_class_name_of(dependents[6]), "GameDeletedRp")
    test.assert_eq(get_class_name_of(dependents[7]), "UpdateTokenRp")
    test.assert_eq(get_class_name_of(dependents[8]), "TokenChangedRp")
    test.assert_eq(get_class_name_of(dependents[9]), "CreateTokenRp")
    test.assert_eq(get_class_name_of(dependents[10]), "DeleteTokenRp")
    test.assert_eq(get_class_name_of(dependents[11]), "TokenCreatedRp")
    test.assert_eq(get_class_name_of(dependents[12]), "TokenDeletedRp")
    test.assert_eq(get_class_name_of(dependents[13]), "UpdateEntryRp")
    test.assert_eq(get_class_name_of(dependents[14]), "EntryChangedRp")
    test.assert_eq(get_class_name_of(dependents[15]), "CreateEntryRp")
    test.assert_eq(get_class_name_of(dependents[16]), "DeleteEntryRp")
    test.assert_eq(get_class_name_of(dependents[17]), "EntryCreatedRp")
    test.assert_eq(get_class_name_of(dependents[18]), "EntryDeletedRp")
    test.assert_eq(get_class_name_of(dependents[19]), "GrantsChangedRp")
    test.assert_eq(get_class_name_of(dependents[20]), "UploadAssetRp")
    test.assert_eq(get_class_name_of(dependents[21]), "DownloadAssetRp")
    test.assert_eq(get_class_name_of(dependents[22]), "DownloadMissingAssetsRp")
    test.assert_eq(get_class_name_of(dependents[23]), "ListAssetsRp")
    test.assert_eq(get_class_name_of(dependents[24]), "CreateAssetFolderRp")
    test.assert_eq(get_class_name_of(dependents[25]), "RenameAssetRp")
    test.assert_eq(get_class_name_of(dependents[26]), "DeleteAssetRp")
    test.assert_eq(getmetatable(dependents[27]), "hook")
    local login_dependents = lifetime.dependents(dependents[1])
    test.assert_eq(#login_dependents, 3)
    test.assert_eq(get_class_name_of(login_dependents[1]), "LoginRp")
    test.assert_eq(get_class_name_of(login_dependents[2]), "LogoutRp")
    test.assert_eq(get_class_name_of(login_dependents[3]), "CreateAccountRp")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(app_mock.asset_manager._upload_asset_rp[session], dependents[20])
    test.assert_eq(connection:get_out_channel():getCount(), 0, "no login before one is asked for")
    session:login("adam", "krause")
    test.assert_eq(connection:get_out_channel():getCount(), 1, "the login request was sent")
    lifetime.destroy(connection)
end)

---@param app_mock AppMock
local function add_screens(app_mock)
    mocks.ensure_love_graphics()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500
    app_mock.screen_manager = ScreenManager()
    app_mock.backstack_manager = BackstackManager()
end

test.case("show_login shows the session's login screen, the same one until it is over; the constructor shows nothing", function()
    local app_mock, connection = make_client()
    add_screens(app_mock)
    local session = Session(connection):attach_lifetime(connection)
    test.assert_eq(app_mock.screen_manager:get_screen(), nil)
    session:show_login()
    local login_screen = assert(app_mock.screen_manager:get_screen())
    test.assert_eq(get_class_name_of(login_screen), "LoginScreen")
    local dependents = lifetime.dependents(session)
    test.assert_eq(dependents[#dependents], login_screen, "anchored to the session, after its procedures")
    session:show_login()
    test.assert_eq(app_mock.screen_manager:get_screen(), login_screen, "shown again, not built again")
    test.assert_eq(#lifetime.dependents(session), #dependents)
    test.assert_eq(connection:get_out_channel():getCount(), 0, "showing the screen sends nothing")
    lifetime.destroy(connection)
    test.assert_false(lifetime.alive(login_screen))
    test.assert_eq(app_mock.screen_manager:get_screen(), nil)
end)

test.case("show_login needs a client session that is not logged in; a login shows the menu and joins nothing", function()
    local app_mock, connection = make_client()
    add_screens(app_mock)
    local session = Session(connection):attach_lifetime(connection)
    session:show_login()
    local login_screen = app_mock.screen_manager:get_screen()
    ---@diagnostic disable-next-line: invisible
    session._login._login_rp.on_login("adam")
    test.assert_true(session:is_logged_in())
    test.assert_false(lifetime.alive(login_screen), "the login destroyed it")
    test.assert_eq(get_class_name_of(app_mock.screen_manager:get_screen()), "UserMenuScreen", "a login lands on the menu")
    test.assert_eq(connection:get_out_channel():getCount(), 0, "no game data before the game is joined")
    test.assert_error(function()
        session:show_login()
    end)
    lifetime.destroy(connection)

    local previous = mocks.install_love_filesystem({})
    local server_mock = mocks.install_app({
        is_client = false,
        is_server = true
    })
    server_mock.asset_manager = AssetManager()
    local server_connection = Connection(mocks.make_channel(), mocks.make_channel())
    local server_session = Session(server_connection):attach_lifetime(server_connection)
    test.assert_error(function()
        server_session:show_login()
    end)
    lifetime.destroy(server_connection)
    mocks.restore_love_filesystem(previous)
end)

test.case("destroying the connection tears the whole tree down, the connection first, then newest first", function()
    local app_mock, connection = make_client()
    local session = Session(connection):attach_lifetime(connection)
    local login = session._login
    local in_channel = connection:get_in_channel() --[[@as FakeChannel]]
    local log = {}
    local unregister = Connection.unregister_request_handler
    connection.unregister_request_handler = function(self, id)
        table.insert(log, "  unregister " .. id)
        return unregister(self, id)
    end

    with_release_log(log, function()
        test.assert_deep_eq(log, {}, "nothing dies before the statement")
        lifetime.destroy(connection)
    end)

    test.assert_deep_eq(log, {
        "Connection:release(destroy)",
        "DeleteAssetRp:release(anchor)",
        "  unregister DeleteAssetRp",
        "RenameAssetRp:release(anchor)",
        "  unregister RenameAssetRp",
        "CreateAssetFolderRp:release(anchor)",
        "  unregister CreateAssetFolderRp",
        "ListAssetsRp:release(anchor)",
        "  unregister ListAssetsRp",
        "DownloadMissingAssetsRp:release(anchor)",
        "  unregister DownloadMissingAssetsRp",
        "DownloadAssetRp:release(anchor)",
        "  unregister DownloadAssetRp",
        "UploadAssetRp:release(anchor)",
        "  unregister UploadAssetRp",
        "GrantsChangedRp:release(anchor)",
        "  unregister GrantsChangedRp",
        "EntryDeletedRp:release(anchor)",
        "  unregister EntryDeletedRp",
        "EntryCreatedRp:release(anchor)",
        "  unregister EntryCreatedRp",
        "DeleteEntryRp:release(anchor)",
        "  unregister DeleteEntryRp",
        "CreateEntryRp:release(anchor)",
        "  unregister CreateEntryRp",
        "EntryChangedRp:release(anchor)",
        "  unregister EntryChangedRp",
        "UpdateEntryRp:release(anchor)",
        "  unregister UpdateEntryRp",
        "TokenDeletedRp:release(anchor)",
        "  unregister TokenDeletedRp",
        "TokenCreatedRp:release(anchor)",
        "  unregister TokenCreatedRp",
        "DeleteTokenRp:release(anchor)",
        "  unregister DeleteTokenRp",
        "CreateTokenRp:release(anchor)",
        "  unregister CreateTokenRp",
        "TokenChangedRp:release(anchor)",
        "  unregister TokenChangedRp",
        "UpdateTokenRp:release(anchor)",
        "  unregister UpdateTokenRp",
        "GameDeletedRp:release(anchor)",
        "  unregister GameDeletedRp",
        "DeleteGameRp:release(anchor)",
        "  unregister DeleteGameRp",
        "CreateGameRp:release(anchor)",
        "  unregister CreateGameRp",
        "ListGamesRp:release(anchor)",
        "  unregister ListGamesRp",
        "GameDataRp:release(anchor)",
        "  unregister GameDataRp",
        "CreateAccountRp:release(anchor)",
        "  unregister CreateAccountRp",
        "LogoutRp:release(anchor)",
        "  unregister LogoutRp",
        "LoginRp:release(anchor)",
        "  unregister LoginRp"
    })
    test.assert_false(lifetime.alive(connection))
    test.assert_false(lifetime.alive(session))
    test.assert_false(lifetime.alive(login))
    test.assert_true(in_channel._released)
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(app_mock.asset_manager._upload_asset_rp[session], nil, "the asset manager's hook cleared the entry")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(next(app_mock.asset_manager._download_asset_rp), nil)
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(next(app_mock.asset_manager._download_missing_assets_rp), nil)
    test.assert_eq(app_mock.update_event:get_handler(connection), nil)
end)

test.case("enter_game ignores data for a login that is over; leave_game needs the game (the whole flow: tests/test-lifetimes.lua)", function()
    local app_mock, connection = make_client()
    local session = Session(connection):attach_lifetime(connection)
    test.assert_false(session:is_logged_in())
    local shown = 0
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    app_mock.screen_manager = {
        show = function()
            shown = shown + 1
        end
    }
    session:enter_game()
    test.assert_eq(shown, 0, "no period, no game screen")
    test.assert_error(function()
        session:leave_game()
    end)
    lifetime.destroy(connection)
end)

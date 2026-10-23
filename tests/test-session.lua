local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local AssetManager = require("data.asset-manager")
local DownloadAssetRp = require("data.download-asset-rp")
local DownloadMissingAssetsRp = require("data.download-missing-assets-rp")
local UploadAssetRp = require("data.upload-asset-rp")
local GameDataRp = require("game.game-data-rp")
local Session = require("game.session")
local LoginRp = require("login.login-rp")
local LogoutRp = require("login.logout-rp")
local Connection = require("networking.connection")

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
    GameDataRp = GameDataRp,
    UploadAssetRp = UploadAssetRp,
    DownloadAssetRp = DownloadAssetRp,
    DownloadMissingAssetsRp = DownloadMissingAssetsRp
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

test.case("a client session owns its login, the game data procedure and the asset procedures, in creation order", function()
    local app_mock, connection = make_client()
    local session = Session(connection):attach_lifetime(connection)
    test.assert_eq(lifetime.format(lifetime.of(session)), "(" .. tostring(connection) .. ", reachable)")
    local dependents = lifetime.dependents(session)
    test.assert_eq(#dependents, 6, "login, game data, three asset procedures and the asset manager's hook")
    test.assert_eq(get_class_name_of(dependents[1]), "Login")
    test.assert_eq(get_class_name_of(dependents[2]), "GameDataRp")
    test.assert_eq(get_class_name_of(dependents[3]), "UploadAssetRp")
    test.assert_eq(get_class_name_of(dependents[4]), "DownloadAssetRp")
    test.assert_eq(get_class_name_of(dependents[5]), "DownloadMissingAssetsRp")
    test.assert_eq(getmetatable(dependents[6]), "hook")
    local login_dependents = lifetime.dependents(dependents[1])
    test.assert_eq(get_class_name_of(login_dependents[1]), "LoginRp")
    test.assert_eq(get_class_name_of(login_dependents[2]), "LogoutRp")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(app_mock.asset_manager._upload_asset_rp[session], dependents[3])
    test.assert_eq(connection:get_out_channel():getCount(), 1, "the auto-login request was sent")
    lifetime.destroy(connection)
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
        "DownloadMissingAssetsRp:release(anchor)",
        "  unregister DownloadMissingAssetsRp",
        "DownloadAssetRp:release(anchor)",
        "  unregister DownloadAssetRp",
        "UploadAssetRp:release(anchor)",
        "  unregister UploadAssetRp",
        "GameDataRp:release(anchor)",
        "  unregister GameDataRp",
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

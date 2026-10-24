local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Asset = require("data.asset")
local AssetManager = require("data.asset-manager")
local Session = require("game.session")
local Connection = require("networking.connection")

---@return GameData
local function game_data()
    return {
        game = {
            page = "P"
        },
        groups = {
            master = {
                title = "Game master",
                permissions = {
                    "read",
                    "write"
                }
            },
            player = {
                title = "Player",
                permissions = {
                    "read",
                    "write:tokens"
                }
            }
        },
        players = {
            adam = {
                name = "Adam",
                auth = mocks.server_auth("adam"),
                group = "master"
            },
            piotr = {
                name = "Piotrek",
                auth = mocks.server_auth("piotr"),
                group = "player"
            }
        },
        pages = {},
        token_properties = {},
        tokens = {}
    }
end

---@param name string
---@param fn fun(side: TestServerSide)
local function server_case(name, fn)
    test.case(name, function()
        local side = mocks.make_server_session(game_data, {
            ["server/assets/world/w.png"] = "W"
        })
        ---@type boolean, any
        local ok, err = pcall(fn, side)
        mocks.finish_server_session(side)
        if not ok then
            error(err, 0)
        end
    end)
end

---@param side TestServerSide
---@return UploadAssetResponse
local function upload(side)
    return mocks.request(side.connection, "UploadAssetRp", {
        path = "token/new.png",
        content = love.data.encode("string", "base64", "N")
    }) --[[@as UploadAssetResponse]]
end

test.suite("UploadAssetRp")

server_case("an upload from a session without write on the assets is refused and writes nothing", function(side)
    test.assert_eq(mocks.log_in(side.connection, "piotr"), "piotr")
    test.assert_false(upload(side).success)
    test.assert_eq(Asset("token/new.png", false):get_type(), nil)
end)

server_case("an upload before the login is refused", function(side)
    test.assert_false(upload(side).success)
    test.assert_eq(Asset("token/new.png", false):get_type(), nil)
end)

server_case("an upload from a session with write on the assets is mounted", function(side)
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    test.assert_true(upload(side).success)
    local asset = Asset("token/new.png", false)
    test.assert_eq(asset:get_type(), "file")
    test.assert_eq(asset:read(), "N")
end)

server_case("an upload onto a folder, or under a bad path, is refused with the reason", function(side)
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    local response = mocks.request(side.connection, "UploadAssetRp", {
        path = "world",
        content = love.data.encode("string", "base64", "N")
    }) --[[@as UploadAssetResponse]]
    test.assert_false(response.success)
    test.assert_eq(response.error, "Cannot upload \"world\": it is a folder")
    test.assert_eq(Asset("world/w.png", false):read(), "W")
    response = mocks.request(side.connection, "UploadAssetRp", {
        path = "../escape.png",
        content = love.data.encode("string", "base64", "N")
    }) --[[@as UploadAssetResponse]]
    test.assert_false(response.success)
    test.assert_eq(response.error, "Cannot upload \"../escape.png\": the name \"..\"")
end)

test.case("the client notifies a refused upload and nothing else", function()
    local client = mocks.install_app()
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    local notifications = mocks.make_notification_manager()
    client.notification_manager = notifications
    client.asset_manager = AssetManager()
    local connection = Connection(mocks.make_channel(), mocks.make_channel())
    local session = Session(connection):attach_lifetime(connection)
    ---@diagnostic disable-next-line: invisible
    local rp = client.asset_manager._upload_asset_rp[session]
    rp:receive_response({
        success = true
    })
    test.assert_deep_eq(notifications.messages, {})
    rp:receive_response({
        success = false
    })
    rp:receive_response({
        success = false,
        error = "Cannot upload \"world\": it is a folder"
    })
    test.assert_deep_eq(notifications.messages, {
        "Not allowed to upload assets",
        "Cannot upload \"world\": it is a folder"
    })
    lifetime.destroy(connection)
end)

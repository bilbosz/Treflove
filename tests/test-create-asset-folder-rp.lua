local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Asset = require("data.asset")

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
                    "read"
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
---@param path string
---@return CreateAssetFolderResponse
local function create(side, path)
    return mocks.request(side.connection, "CreateAssetFolderRp", {
        path = path
    }) --[[@as CreateAssetFolderResponse]]
end

test.suite("CreateAssetFolderRp")

server_case("a folder from a session without write on the assets is refused", function(side)
    test.assert_eq(mocks.log_in(side.connection, "piotr"), "piotr")
    local response = create(side, "maps")
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not allowed to change assets")
    test.assert_eq(Asset("maps", false):get_type(), nil)
end)

server_case("a writer makes a folder, with its parents, and gets it back in the listing", function(side)
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    local response = create(side, "maps/old")
    test.assert_true(response.success)
    test.assert_eq(response.error, nil)
    test.assert_eq(response.path, "maps/old")
    test.assert_eq(Asset("maps/old", false):get_type(), "directory")
    local listing = mocks.request(side.connection, "ListAssetsRp", {}) --[[@as ListAssetsResponse]]
    test.assert_deep_eq(listing.entries[1], {
        path = "maps",
        type = "directory"
    })
    test.assert_deep_eq(listing.entries[2], {
        path = "maps/old",
        type = "directory"
    })
end)

server_case("a folder that exists, or an asset's name, or a bad path, is refused with the reason", function(side)
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    test.assert_eq(create(side, "world").error, "Cannot create \"world\": it exists already")
    test.assert_eq(create(side, "world/w.png").error, "Cannot create \"world/w.png\": it exists already")
    test.assert_eq(create(side, "../outside").error, "Cannot create \"../outside\": the name \"..\"")
    test.assert_eq(create(side, "").error, "Cannot create \"\": an empty path")
end)

test.case("the client notifies a refused folder with the server's reason", function()
    local side = mocks.make_client_session({})
    ---@diagnostic disable-next-line: invisible
    local rp = side.client.asset_manager._create_asset_folder_rp[side.session]
    rp:receive_response({
        success = true,
        path = "maps"
    })
    test.assert_deep_eq(side.notifications.messages, {})
    rp:receive_response({
        success = false,
        error = "Cannot create \"maps\": it exists already",
        path = "maps"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Cannot create \"maps\": it exists already"
    })
    mocks.finish_client_session(side)
end)

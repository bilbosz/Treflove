local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

---@return GameData
local function game_data()
    return {
        name = "G",
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
            },
            blind = {
                title = "Blind",
                permissions = {
                    "read:pages"
                }
            }
        },
        players = {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player"
            },
            ewa = {
                group = "blind"
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
            ["s/games/g/assets/world/w.png"] = "W",
            ["s/games/g/assets/token/t.png"] = "T"
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
---@return ListAssetsResponse
local function list(side)
    return mocks.request(side.connection, "ListAssetsRp", {}) --[[@as ListAssetsResponse]]
end

test.suite("ListAssetsRp")

server_case("before the login, and without read on the assets, the listing is refused", function(side)
    local response = list(side)
    test.assert_false(response.success)
    test.assert_eq(response.entries, nil)
    test.assert_true(mocks.join_game(side.connection, "ewa").success)
    response = list(side)
    test.assert_false(response.success)
    test.assert_false(response.writable)
end)

server_case("a reader is sent the whole store, parents first, and that it may not change it", function(side)
    test.assert_true(mocks.join_game(side.connection, "piotr").success)
    local response = list(side)
    test.assert_true(response.success)
    test.assert_false(response.writable)
    test.assert_deep_eq(response.entries, {
        {
            path = "token",
            type = "directory"
        },
        {
            path = "token/t.png",
            type = "file",
            size = 1
        },
        {
            path = "world",
            type = "directory"
        },
        {
            path = "world/w.png",
            type = "file",
            size = 1
        }
    })
end)

server_case("a writer is told so", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    local response = list(side)
    test.assert_true(response.success)
    test.assert_true(response.writable)
    test.assert_eq(#response.entries, 4)
end)

test.case("the client notifies a refused listing and nothing else", function()
    local side = mocks.make_client_session({})
    ---@diagnostic disable-next-line: invisible
    local rp = side.client.asset_manager._list_assets_rp[side.session]
    rp:receive_response({
        success = true,
        entries = {},
        writable = true
    })
    test.assert_deep_eq(side.notifications.messages, {})
    rp:receive_response({
        success = false,
        writable = false
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Not allowed to browse assets"
    })
    mocks.finish_client_session(side)
end)

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
            }
        },
        players = {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player"
            }
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
            avatar = {
                title = "Avatar",
                type = "image"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 3,
                avatar = "token/t.png",
                position = {
                    1,
                    2
                }
            }
        }
    }
end

---@param name string
---@param fn fun(side: TestServerSide)
local function server_case(name, fn)
    test.case(name, function()
        local side = mocks.make_server_session(game_data, {
            ["s/games/g/assets/world/w.png"] = "W",
            ["s/games/g/assets/token/t.png"] = "T",
            ["s/games/g/assets/token/x.png"] = "X",
            ["s/games/g/assets/drafts/a.png"] = "A",
            ["s/games/g/assets/drafts/b.png"] = "B"
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
---@return DeleteAssetResponse
local function delete(side, path)
    return mocks.request(side.connection, "DeleteAssetRp", {
        path = path
    }) --[[@as DeleteAssetResponse]]
end

test.suite("DeleteAssetRp")

server_case("a delete from a session without write on the assets is refused", function(side)
    test.assert_true(mocks.join_game(side.connection, "piotr").success)
    local response = delete(side, "token/x.png")
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not allowed to change assets")
    test.assert_eq(mocks.server_store():asset("token/x.png"):read(), "X")
end)

server_case("a writer deletes an unused file, and a folder with everything under it", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    local response = delete(side, "token/x.png")
    test.assert_true(response.success)
    test.assert_eq(response.path, "token/x.png")
    test.assert_eq(mocks.server_store():asset("token/x.png"):get_type(), nil)
    test.assert_true(delete(side, "drafts").success)
    test.assert_eq(mocks.server_store():asset("drafts"):get_type(), nil)
    test.assert_eq(mocks.server_store():asset("drafts/a.png"):get_type(), nil)
end)

server_case("an asset the game uses stays, and so does a folder with one under it", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    test.assert_eq(delete(side, "world/w.png").error, "Cannot delete \"world/w.png\": used by page \"P\"")
    test.assert_eq(delete(side, "token").error, "Cannot delete \"token\": used by token \"T\" (avatar)")
    test.assert_eq(mocks.server_store():asset("world/w.png"):read(), "W")
    test.assert_eq(mocks.server_store():asset("token/t.png"):read(), "T")
end)

server_case("deleting what is not there, or a bad path, is refused with the reason", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    test.assert_eq(delete(side, "token/none.png").error, "Cannot delete \"token/none.png\": there is no such asset")
    test.assert_eq(delete(side, "../save.lua").error, "Cannot delete \"../save.lua\": the name \"..\"")
end)

test.case("the client's copy goes with a deleted asset; a refusal is notified", function()
    local side = mocks.make_client_session({
        ["c/games/g/assets/token/x.png"] = "X",
        ["c/games/g/assets/drafts/a.png"] = "A"
    })
    ---@diagnostic disable-next-line: invisible
    local rp = side.client.asset_manager._delete_asset_rp[side.session]
    rp:receive_response({
        success = true,
        path = "token/x.png"
    })
    test.assert_eq(mocks.client_store():asset("token/x.png"):get_type(), nil)
    rp:receive_response({
        success = true,
        path = "drafts"
    })
    test.assert_eq(mocks.client_store():asset("drafts/a.png"):get_type(), nil)
    rp:receive_response({
        success = true,
        path = "never/downloaded.png"
    })
    test.assert_deep_eq(side.notifications.messages, {})
    rp:receive_response({
        success = false,
        error = "Cannot delete \"world/w.png\": used by page \"P\"",
        path = "world/w.png"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Cannot delete \"world/w.png\": used by page \"P\""
    })
    mocks.finish_client_session(side)
end)

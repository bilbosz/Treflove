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
            ["s/games/g/assets/token/x.png"] = "X"
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
---@param new_path string
---@return RenameAssetResponse
local function rename(side, path, new_path)
    return mocks.request(side.connection, "RenameAssetRp", {
        path = path,
        new_path = new_path
    }) --[[@as RenameAssetResponse]]
end

test.suite("RenameAssetRp")

server_case("a rename from a session without write on the assets is refused", function(side)
    test.assert_true(mocks.join_game(side.connection, "piotr").success)
    local response = rename(side, "token/x.png", "token/y.png")
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not allowed to change assets")
    test.assert_eq(mocks.server_store():asset("token/x.png"):read(), "X")
end)

server_case("a writer renames a file, and the game keeps pointing at it", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    local response = rename(side, "token/t.png", "token/u.png")
    test.assert_true(response.success)
    test.assert_eq(response.path, "token/t.png")
    test.assert_eq(response.new_path, "token/u.png")
    test.assert_eq(mocks.server_store():asset("token/t.png"):get_type(), nil)
    test.assert_eq(mocks.server_store():asset("token/u.png"):read(), "T")
    test.assert_eq(side.session:get_game():get_data().tokens.T.avatar, "token/u.png")
    test.assert_eq(side.session:get_game():get_data().pages.P.image, "world/w.png")
    local saved = table.from_string(assert(love.filesystem.read("s/games/g/save.lua"))) --[[@as GameData]]
    test.assert_eq(saved.tokens.T.avatar, "token/u.png", "the game is saved with the new path")
end)

server_case("a renamed folder takes its content along, and the game follows every asset under it", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    test.assert_true(rename(side, "token", "people/old").success)
    test.assert_eq(mocks.server_store():asset("token"):get_type(), nil)
    test.assert_eq(mocks.server_store():asset("people/old/t.png"):read(), "T")
    test.assert_eq(mocks.server_store():asset("people/old/x.png"):read(), "X")
    test.assert_eq(side.session:get_game():get_data().tokens.T.avatar, "people/old/t.png")
end)

server_case("a rename needs a source, a free destination outside the source, and good paths", function(side)
    test.assert_true(mocks.join_game(side.connection, "adam").success)
    test.assert_eq(rename(side, "token/none.png", "token/y.png").error, "Cannot rename \"token/none.png\": there is no such asset")
    test.assert_eq(rename(side, "token/x.png", "token/t.png").error, "Cannot rename \"token/x.png\" to \"token/t.png\": it exists already")
    test.assert_eq(rename(side, "token", "token/sub").error, "Cannot rename \"token\" to \"token/sub\": it would end up under itself")
    test.assert_eq(rename(side, "token/x.png", "../x.png").error, "Cannot rename \"token/x.png\" to \"../x.png\": the name \"..\"")
    test.assert_eq(mocks.server_store():asset("token/x.png"):read(), "X")
    test.assert_eq(side.session:get_game():get_data().tokens.T.avatar, "token/t.png")
end)

test.case("the client's copy follows a rename, replacing a stale copy under the new name; a refusal is notified", function()
    local side = mocks.make_client_session({
        ["c/games/g/assets/token/t.png"] = "T",
        ["c/games/g/assets/token/stale.png"] = "OLD"
    })
    ---@diagnostic disable-next-line: invisible
    local rp = side.client.asset_manager._rename_asset_rp[side.session]
    rp:receive_response({
        success = true,
        path = "token/t.png",
        new_path = "token/stale.png"
    })
    test.assert_eq(mocks.client_store():asset("token/t.png"):get_type(), nil)
    test.assert_eq(mocks.client_store():asset("token/stale.png"):read(), "T")
    rp:receive_response({
        success = true,
        path = "token/never-downloaded.png",
        new_path = "token/elsewhere.png"
    })
    test.assert_eq(mocks.client_store():asset("token/elsewhere.png"):get_type(), nil, "nothing to move")
    test.assert_deep_eq(side.notifications.messages, {})
    rp:receive_response({
        success = false,
        error = "Cannot rename \"a\" to \"b\": it exists already",
        path = "a",
        new_path = "b"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Cannot rename \"a\" to \"b\": it exists already"
    })
    mocks.finish_client_session(side)
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

---@return GameData
local function game_data()
    return {
        name = "Meadow",
        game = {
            page = "P"
        },
        groups = {},
        players = {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player"
            }
        },
        pages = {},
        token_properties = {},
        tokens = {}
    }
end

---@param name string
---@return string
local function save_of(name)
    local data = game_data()
    data.name = name
    data.players = {
        adam = {
            group = "master"
        }
    }
    return table.to_string(data)
end

---@param side TestServerSide
---@return GameInfo[]
local function list(side)
    return (mocks.request(side.connection, "ListGamesRp", {}) --[[@as ListGamesResponse]] ).games
end

test.suite("ListGamesRp")

test.case("a logged-in session gets every game by name, then by id, and whether it plays in it; before the login, none", function()
    local side = mocks.make_server_session(game_data, {
        ["s/games/a-zoo/save.lua"] = save_of("A Zoo"),
        ["s/games/a-zoo-2/save.lua"] = save_of("A Zoo")
    })
    test.assert_deep_eq(list(side), {})
    test.assert_eq(mocks.log_in(side.connection, "piotr"), "piotr")
    test.assert_deep_eq(list(side), {
        {
            id = "a-zoo",
            name = "A Zoo",
            member = false
        },
        {
            id = "a-zoo-2",
            name = "A Zoo",
            member = false
        },
        {
            id = mocks.GAME_ID,
            name = "Meadow",
            member = true
        }
    })
    mocks.finish_server_session(side)
end)

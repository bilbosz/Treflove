local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

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
                    "read:game",
                    "read:pages"
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
                group = "player",
                permissions = {
                    "read:tokens/T"
                }
            }
        },
        pages = {
            P = {
                name = "P",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "T",
                    "U"
                }
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
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
            },
            U = {
                name = "U",
                diameter = 2,
                avatar = "token/u.png",
                position = {
                    3,
                    4
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

test.suite("GameDataRp")

server_case("a master is sent the whole game data without the players' auth, and its grants", function(side)
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    local response = mocks.request(side.connection, "GameDataRp", {}) --[[@as GameDataResponse]]
    local expected = game_data()
    for _, player in pairs(expected.players) do
        player.auth = nil
    end
    test.assert_deep_eq(response.data, expected)
    test.assert_deep_eq(response.permissions, {
        "read",
        "write"
    })
    test.assert_true(side.server.data.players.adam.auth ~= nil, "the server's own data keeps the auth")
end)

server_case("a player is sent only what it reads: one token, the page listing only it, the group's grants and its own", function(side)
    test.assert_eq(mocks.log_in(side.connection, "piotr"), "piotr")
    local response = mocks.request(side.connection, "GameDataRp", {}) --[[@as GameDataResponse]]
    local full = game_data()
    test.assert_deep_eq(response.data, {
        game = full.game,
        groups = {},
        players = {},
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
        token_properties = {},
        tokens = {
            T = full.tokens.T
        }
    })
    test.assert_deep_eq(response.permissions, {
        "read:game",
        "read:pages",
        "read:tokens/T"
    })
    test.assert_deep_eq(side.server.data.pages.P.tokens, {
        "T",
        "U"
    }, "the server's own page is untouched")
end)

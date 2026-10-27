local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Control = require("controls.control")
local Accounts = require("data.accounts")
local Asset = require("data.asset")
local permissions = require("game.permissions")
local ScreenManager = require("screens.screen-manager")
local BackstackManager = require("utils.backstack-manager")

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
                    "read:game",
                    "read:pages"
                }
            }
        },
        players = {
            adam = {
                group = "master"
            },
            piotr = {
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
                owners = {
                    "piotr"
                },
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
            ["s/games/g/assets/world/w.png"] = "W"
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
---@param id string
---@return GameDataResponse
local function ask(side, id)
    return mocks.request(side.connection, "GameDataRp", {
        game = id
    }) --[[@as GameDataResponse]]
end

test.suite("GameDataRp")

server_case("a master is sent the whole game data with its name, and its grants", function(side)
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    local response = ask(side, mocks.GAME_ID)
    test.assert_true(response.success)
    test.assert_eq(response.game, mocks.GAME_ID)
    test.assert_deep_eq(response.data, game_data())
    test.assert_deep_eq(response.permissions, {
        "read",
        "write"
    })
    test.assert_eq(side.session:get_game():get_id(), mocks.GAME_ID, "the session is in the game")
end)

server_case("a player is sent only what it reads: one token, the page listing only it, the group's grants and its own", function(side)
    test.assert_eq(mocks.log_in(side.connection, "piotr"), "piotr")
    local response = ask(side, mocks.GAME_ID)
    local full = game_data()
    test.assert_deep_eq(response.data, {
        name = "G",
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
    test.assert_deep_eq(side.session:get_game():get_data().pages.P.tokens, {
        "T",
        "U"
    }, "the server's own page is untouched")
end)

server_case("a game is joined only after the login, and only one the server has", function(side)
    test.assert_deep_eq(ask(side, mocks.GAME_ID), {
        success = false,
        error = "Not logged in",
        game = mocks.GAME_ID
    })
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    for _, id in ipairs({
        "none",
        "../g",
        "G"
    }) do
        test.assert_deep_eq(ask(side, id), {
            success = false,
            error = "No such game",
            game = id
        }, id)
    end
    test.assert_false(side.session:is_in_game())
    test.assert_false(side.session:is_allowed(permissions.Action.READ), "no grants before a game")
end)

server_case("a first join adds the account to the game's players in the group player, saved; a second changes nothing", function(side)
    local accounts = love.filesystem.read("s/accounts.lua")
    love.filesystem.write("s/accounts.lua", mocks.accounts_file({
        "adam",
        "piotr",
        "ewa"
    }))
    side.server.accounts = Accounts(Asset("s/accounts.lua"))
    test.assert_true(accounts ~= nil)
    test.assert_eq(mocks.log_in(side.connection, "ewa"), "ewa")
    local response = ask(side, mocks.GAME_ID)
    test.assert_true(response.success)
    test.assert_deep_eq(response.permissions, {
        "read:game",
        "read:pages"
    }, "the player group's grants")
    local saved = table.from_string(assert(love.filesystem.read("s/games/g/save.lua"))) --[[@as GameData]]
    test.assert_deep_eq(saved.players.ewa, {
        group = "player"
    })
    test.assert_true(ask(side, mocks.GAME_ID).success)
    test.assert_deep_eq(side.session:get_game():get_data().players.ewa, {
        group = "player"
    })
end)

test.case("the client: a refusal is notified and the menu shown again; the data sets the grants and the store of the game", function()
    local side = mocks.make_client_session({
        ["c/games/h/assets/world/w.png"] = "W",
        ["c/games/h/assets/token/t.png"] = "T"
    })
    local client = side.client
    mocks.ensure_love_graphics()
    client.root = Control()
    client.width, client.height = 2000, 1500
    client.screen_manager = ScreenManager()
    client.backstack_manager = BackstackManager()
    ---@diagnostic disable-next-line: invisible
    side.session._login._login_rp.on_login("piotr")
    ---@diagnostic disable-next-line: invisible
    local rp = side.session._game_data_rp
    rp:receive_response({
        success = false,
        error = "No such game",
        game = "x"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "No such game"
    })
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "UserMenuScreen")
    test.assert_eq(client.data, nil)
    rp:receive_response({
        success = true,
        game = "h",
        data = game_data(),
        permissions = {
            "read:tokens/@owned"
        }
    })
    test.assert_eq(assert(client.data).name, "G")
    test.assert_eq(assert(client.asset_manager:get_store()):get_root(), "c/games/h")
    test.assert_true(side.session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, "T"), "piotr owns T in the data received")
    test.assert_false(side.session:is_allowed(permissions.Action.READ, permissions.Kind.TOKENS, "U"))
    test.assert_eq(get_class_name_of(client.screen_manager:get_screen()), "WaitingScreen")
    local payload = side.connection:get_out_channel():pop() --[[@as string]]
    local request = mocks.decode_request(payload)
    test.assert_eq(request.id, "DownloadMissingAssetsRp")
    test.assert_deep_eq(request.body, {
        list = {
            "token/u.png"
        }
    }, "what the game's store lacks")
    mocks.finish_client_session(side)
end)

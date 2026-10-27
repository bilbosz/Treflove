local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local game_client = require("tests.lib.game-client")
local lifetime = require("lifetime")

local SAVE = "s/games/g/save.lua"

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
                    "read:pages",
                    "read:tokens/@owned",
                    "write:tokens/@owned"
                }
            },
            watcher = {
                title = "Watcher",
                permissions = {
                    "read",
                    "view:tokens/T"
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
                    "view:tokens/T",
                    "read:tokens/U"
                }
            },
            ewa = {
                group = "watcher"
            },
            olga = {
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
                    "T",
                    "U"
                }
            },
            Q = {
                name = "Q",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "U",
                    "T"
                }
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            },
            diameter = {
                title = "Diameter",
                type = "number"
            },
            avatar = {
                title = "Avatar",
                type = "image"
            },
            owners = {
                title = "Owners",
                type = "array"
            },
            position = {
                title = "Position",
                type = "array"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 1,
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

---@class TestDeleteTokenServer
---@field side TestServerSide
---@field files table<string, string> The fake file system, `SAVE` among them

---@param name string
---@param fn fun(server: TestDeleteTokenServer)
local function server_case(name, fn)
    test.case(name, function()
        ---@type table<string, string>
        local files = {
            ["s/games/g/assets/world/w.png"] = "W"
        }
        local side = mocks.make_server_session(game_data, files)
        ---@type boolean, any
        local ok, err = pcall(fn, {
            side = side,
            files = files
        })
        mocks.finish_server_session(side)
        if not ok then
            error(err, 0)
        end
    end)
end

---@param server TestDeleteTokenServer
---@return GameData The server's own
local function server_data(server)
    return assert(assert(server.side.server.games):get(mocks.GAME_ID)):get_data()
end

---@param server TestDeleteTokenServer
---@return GameData What `save.lua` holds
local function saved(server)
    return table.from_string(assert(server.files[SAVE])) --[[@as GameData]]
end

---@param connection Connection
---@param id string
---@return DeleteTokenResponse
local function delete(connection, id)
    return mocks.request(connection, "DeleteTokenRp", {
        id = id
    }) --[[@as DeleteTokenResponse]]
end

---@param connection Connection
---@param id string
local function assert_pushed(connection, id)
    local pushes = mocks.sent(connection)
    test.assert_eq(#pushes, 1)
    test.assert_eq(pushes[1].source, "s")
    test.assert_eq(pushes[1].id, "TokenDeletedRp")
    test.assert_deep_eq(pushes[1].body, {
        id = id
    })
end

test.suite("DeleteTokenRp")

server_case("a master deletes a token: the entry, every page's list and the grants on it go from the data and the save", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = delete(server.side.connection, "T")
    test.assert_deep_eq(response, {
        success = true,
        id = "T"
    })
    for _, data in ipairs({
        server_data(server),
        saved(server)
    }) do
        test.assert_eq(data.tokens.T, nil)
        test.assert_deep_eq(data.tokens.U, game_data().tokens.U)
        test.assert_deep_eq(data.pages.P.tokens, {
            "U"
        })
        test.assert_deep_eq(data.pages.Q.tokens, {
            "U"
        })
        test.assert_deep_eq(data.groups.watcher.permissions, {
            "read"
        })
        test.assert_deep_eq(data.groups.player.permissions, game_data().groups.player.permissions)
        test.assert_deep_eq(data.players.piotr.permissions, {
            "read:tokens/U"
        })
    end
end)

server_case("the push goes to the other sessions that read the token before it went, ownership included; every live session's set loses the grants on it", function(server)
    local piotr_connection, piotr = mocks.join_another("piotr")
    local ewa_connection, ewa = mocks.join_another("ewa")
    local olga_connection = mocks.join_another("olga")
    mocks.join_game(server.side.connection, "adam")
    for _, connection in ipairs({
        piotr_connection,
        ewa_connection,
        olga_connection
    }) do
        mocks.sent(connection)
    end
    delete(server.side.connection, "T")
    test.assert_eq(server.side.connection:get_out_channel():getCount(), 0, "the response only, popped by the request")
    assert_pushed(piotr_connection, "T")
    assert_pushed(ewa_connection, "T")
    test.assert_deep_eq(mocks.sent(olga_connection), {}, "olga owns nothing")
    test.assert_deep_eq(piotr:get_permissions():get_grants(), {
        "read:game",
        "read:pages",
        "read:tokens/@owned",
        "write:tokens/@owned",
        "read:tokens/U"
    })
    test.assert_deep_eq(ewa:get_permissions():get_grants(), {
        "read"
    })
    test.assert_deep_eq(server.side.session:get_permissions():get_grants(), {
        "read",
        "write"
    })
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
    lifetime.destroy(olga_connection)
end)

server_case("a token read through a grant on its id is pushed to its reader", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local olga_connection = mocks.join_another("olga")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(olga_connection)
    delete(server.side.connection, "U")
    assert_pushed(piotr_connection, "U")
    test.assert_deep_eq(mocks.sent(olga_connection), {})
    lifetime.destroy(piotr_connection)
    lifetime.destroy(olga_connection)
end)

server_case("a player deletes a token they own, which writes it", function(server)
    local adam_connection = mocks.join_another("adam")
    mocks.join_game(server.side.connection, "piotr")
    mocks.sent(adam_connection)
    local response = delete(server.side.connection, "T")
    test.assert_true(response.success)
    test.assert_eq(server_data(server).tokens.T, nil)
    assert_pushed(adam_connection, "T")
    lifetime.destroy(adam_connection)
end)

server_case("a session not in a game, an unknown id and a token the session does not write are refused, nothing applied", function(server)
    local ewa_connection = mocks.join_another("ewa")
    mocks.sent(ewa_connection)
    local before = server.files[SAVE]
    test.assert_deep_eq(delete(server.side.connection, "T"), {
        success = false,
        error = "Not in a game",
        id = "T"
    })
    mocks.log_in(server.side.connection, "piotr")
    test.assert_eq(delete(server.side.connection, "T").error, "Not in a game")
    mocks.request(server.side.connection, "GameDataRp", {
        game = mocks.GAME_ID
    })
    test.assert_deep_eq(delete(server.side.connection, "Nobody"), {
        success = false,
        error = "No token with the id \"Nobody\"",
        id = "Nobody"
    })
    test.assert_deep_eq(delete(server.side.connection, "U"), {
        success = false,
        error = "Not allowed to delete the token \"U\"",
        id = "U"
    })
    test.assert_deep_eq(server_data(server), game_data())
    test.assert_eq(server.files[SAVE], before)
    test.assert_deep_eq(mocks.sent(ewa_connection), {})
    test.assert_deep_eq(server.side.session:get_permissions():get_grants(), {
        "read:game",
        "read:pages",
        "read:tokens/@owned",
        "write:tokens/@owned",
        "view:tokens/T",
        "read:tokens/U"
    })
    lifetime.destroy(ewa_connection)
end)

server_case("a request from the server's peer for the push is logged and acknowledged with nothing", function(server)
    mocks.join_game(server.side.connection, "adam")
    test.assert_deep_eq(mocks.request(server.side.connection, "TokenDeletedRp", {
        id = "T"
    }), {})
    test.assert_deep_eq(server.side.server.logs[#server.side.server.logs], {
        "TokenDeletedRp is the server's to send: a request from the client ignored"
    })
    test.assert_true(server_data(server).tokens.T ~= nil)
end)

test.suite("DeleteTokenRp, the client")

---@param name string
---@param grants string[]
---@param fn fun(client: GameClient)
local function client_case(name, grants, fn)
    test.case(name, function()
        local client = game_client.enter(grants)
        ---@type boolean, any
        local ok, err = pcall(fn, client)
        game_client.finish(client)
        if not ok then
            error(err, 0)
        end
    end)
end

---@param client GameClient
---@return string[] The notifications since the last call
local function notified(client)
    local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
    local messages = notifications.messages
    notifications.messages = {}
    return messages
end

client_case("delete_token sends the id; the answer removes the token from the page and the data", {
    "read",
    "write"
}, function(client)
    notified(client)
    local page = client.game_screen:get_page()
    local smaug = game_client.find_token(client, "Smaug")
    client.session:delete_token("Smaug")
    test.assert_deep_eq(game_client.pop_request(client, "DeleteTokenRp"), {
        id = "Smaug"
    })
    test.assert_true(lifetime.alive(smaug), "nothing before the answer")
    game_client.answer(client, "DeleteTokenRp", {
        success = true,
        id = "Smaug"
    })
    test.assert_false(lifetime.alive(smaug))
    test.assert_eq(page:try_find_token("Smaug"), nil)
    local data = assert(client.app.data)
    test.assert_eq(data.tokens.Smaug, nil)
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza"
    })
    test.assert_deep_eq(notified(client), {})
end)

client_case("a refusal is notified and the token stays", {
    "read"
}, function(client)
    notified(client)
    local smaug = game_client.find_token(client, "Smaug")
    client.session:delete_token("Smaug")
    game_client.pop_request(client, "DeleteTokenRp")
    game_client.answer(client, "DeleteTokenRp", {
        success = false,
        error = "Not allowed to delete the token \"Smaug\"",
        id = "Smaug"
    })
    test.assert_deep_eq(notified(client), {
        "Not allowed to delete the token \"Smaug\""
    })
    test.assert_true(lifetime.alive(smaug))
    test.assert_deep_eq(assert(client.app.data).tokens, game_client.game_data().tokens)
end)

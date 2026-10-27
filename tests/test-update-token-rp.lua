local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local game_client = require("tests.lib.game-client")
local lifetime = require("lifetime")
local Consts = require("app.consts")

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
                    "read:tokens/@owned"
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
                    "view:tokens/T"
                }
            },
            ewa = {
                group = "watcher"
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

---@class TestUpdateTokenServer
---@field side TestServerSide
---@field files table<string, string> The fake file system, `SAVE` among them

---@param name string
---@param fn fun(server: TestUpdateTokenServer)
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

---@param server TestUpdateTokenServer
---@return GameData The server's own
local function server_data(server)
    return assert(assert(server.side.server.games):get(mocks.GAME_ID)):get_data()
end

---@param server TestUpdateTokenServer
---@return GameData What `save.lua` holds
local function saved(server)
    return table.from_string(assert(server.files[SAVE])) --[[@as GameData]]
end

---@param connection Connection
---@param request UpdateTokenRequest
---@return UpdateTokenResponse
local function update(connection, request)
    return mocks.request(connection, "UpdateTokenRp", request) --[[@as UpdateTokenResponse]]
end

test.suite("UpdateTokenRp")

server_case("a master moves a token and renames its fields: the data, the save and the response's token", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = update(server.side.connection, {
        id = "U",
        changes = {
            position = {
                5,
                6
            },
            name = "Ursula",
            diameter = 3,
            avatar = "token/t.png"
        }
    })
    test.assert_true(response.success)
    test.assert_eq(response.id, "U")
    test.assert_eq(response.new_id, nil)
    local expected = game_data().tokens.U
    expected.position = {
        5,
        6
    }
    expected.name = "Ursula"
    expected.diameter = 3
    expected.avatar = "token/t.png"
    test.assert_deep_eq(response.token, expected)
    test.assert_deep_eq(server_data(server).tokens.U, expected)
    test.assert_deep_eq(saved(server).tokens.U, expected)
    test.assert_deep_eq(saved(server).tokens.T, game_data().tokens.T, "the other token as it was")
end)

server_case("a player without write is refused with the reason, the data and the save untouched; the token comes back only when it reads it", function(server)
    mocks.join_game(server.side.connection, "piotr")
    local before = server.files[SAVE]
    local response = update(server.side.connection, {
        id = "T",
        changes = {
            position = {
                5,
                6
            }
        }
    })
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not allowed to change the token \"T\"")
    test.assert_eq(response.id, "T")
    test.assert_deep_eq(response.token, game_data().tokens.T, "owned, so read: what to restore")
    response = update(server.side.connection, {
        id = "U",
        changes = {
            name = "Mine"
        }
    })
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not allowed to change the token \"U\"")
    test.assert_eq(response.token, nil, "not read, not sent")
    test.assert_deep_eq(server_data(server).tokens, game_data().tokens)
    test.assert_eq(server.files[SAVE], before)
end)

server_case("a session not in a game is refused, logged in or not", function(server)
    local request = {
        id = "T",
        changes = {
            name = "X"
        }
    }
    local response = update(server.side.connection, request)
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not in a game")
    test.assert_eq(response.token, nil)
    mocks.log_in(server.side.connection, "adam")
    response = update(server.side.connection, request)
    test.assert_eq(response.error, "Not in a game")
    test.assert_deep_eq(server_data(server).tokens, game_data().tokens)
end)

server_case("an unknown id is refused", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = update(server.side.connection, {
        id = "Nobody",
        changes = {
            name = "X"
        }
    })
    test.assert_false(response.success)
    test.assert_eq(response.error, "No token with the id \"Nobody\"")
    test.assert_eq(response.token, nil)
end)

server_case("a change outside the changeable properties, of an array property, of a wrong type or a malformed position is refused, and nothing of the request applies", function(server)
    mocks.join_game(server.side.connection, "adam")
    local before = server.files[SAVE]
    ---@type {key: string, value: TokenDataValue}[]
    local bad = {
        {
            key = "speed",
            value = 3
        },
        {
            key = "owners",
            value = {
                "adam"
            }
        },
        {
            key = "name",
            value = 5
        },
        {
            key = "diameter",
            value = "big"
        },
        {
            key = "avatar",
            value = 1
        },
        {
            key = "position",
            value = {
                1
            }
        },
        {
            key = "position",
            value = {
                1,
                "2"
            }
        },
        {
            key = "position",
            value = "here"
        }
    }
    for _, change in ipairs(bad) do
        local response = update(server.side.connection, {
            id = "T",
            changes = {
                name = "Applied?",
                [change.key] = change.value
            }
        })
        test.assert_false(response.success, change.key)
        test.assert_eq(response.error, string.format("Cannot change %q of the token \"T\"", change.key))
        test.assert_deep_eq(response.token, game_data().tokens.T)
    end
    test.assert_deep_eq(server_data(server).tokens, game_data().tokens)
    test.assert_eq(server.files[SAVE], before)
end)

server_case("a rename renames the data, the page's list, the grants, the save and the sets of every live session of the game", function(server)
    local other_connection, other = mocks.join_another("piotr")
    mocks.join_game(server.side.connection, "adam")
    local response = update(server.side.connection, {
        id = "T",
        new_id = "Tom",
        changes = {
            position = {
                7,
                8
            }
        }
    })
    test.assert_true(response.success)
    test.assert_eq(response.id, "T")
    test.assert_eq(response.new_id, "Tom")
    local expected = game_data().tokens.T
    expected.position = {
        7,
        8
    }
    test.assert_deep_eq(response.token, expected)
    for _, data in ipairs({
        server_data(server),
        saved(server)
    }) do
        test.assert_eq(data.tokens.T, nil)
        test.assert_deep_eq(data.tokens.Tom, expected)
        test.assert_deep_eq(data.pages.P.tokens, {
            "Tom",
            "U"
        })
        test.assert_deep_eq(data.groups.watcher.permissions, {
            "read",
            "view:tokens/Tom"
        })
        test.assert_deep_eq(data.players.piotr.permissions, {
            "view:tokens/Tom"
        })
    end
    test.assert_deep_eq(other:get_permissions():get_grants(), {
        "read:game",
        "read:pages",
        "read:tokens/@owned",
        "view:tokens/Tom"
    })
    test.assert_deep_eq(server.side.session:get_permissions():get_grants(), {
        "read",
        "write"
    })
    lifetime.destroy(other_connection)
end)

server_case("a rename to a taken id or an empty one is refused with the reason, nothing applied", function(server)
    mocks.join_game(server.side.connection, "adam")
    local before = server.files[SAVE]
    local response = update(server.side.connection, {
        id = "T",
        new_id = "U",
        changes = {
            name = "X"
        }
    })
    test.assert_false(response.success)
    test.assert_eq(response.error, "A token with the id \"U\" already exists")
    test.assert_eq(response.new_id, "U")
    test.assert_deep_eq(response.token, game_data().tokens.T)
    response = update(server.side.connection, {
        id = "T",
        new_id = "",
        changes = {}
    })
    test.assert_eq(response.error, "An id must not be empty")
    test.assert_deep_eq(server_data(server).tokens, game_data().tokens)
    test.assert_eq(server.files[SAVE], before)
end)

server_case("an accepted change is pushed to every other session of the game that reads the token, the requester gets the response only", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local ewa_connection = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(ewa_connection)
    update(server.side.connection, {
        id = "T",
        changes = {
            name = "Tilly"
        }
    })
    test.assert_eq(server.side.connection:get_out_channel():getCount(), 0, "the response only, popped by the request")
    local expected = game_data().tokens.T
    expected.name = "Tilly"
    for _, connection in ipairs({
        piotr_connection,
        ewa_connection
    }) do
        local pushes = mocks.sent(connection)
        test.assert_eq(#pushes, 1)
        test.assert_eq(pushes[1].source, "s")
        test.assert_eq(pushes[1].id, "TokenChangedRp")
        test.assert_deep_eq(pushes[1].body, {
            id = "T",
            token = expected
        })
    end

    update(server.side.connection, {
        id = "U",
        new_id = "Ursula",
        changes = {}
    })
    test.assert_deep_eq(mocks.sent(piotr_connection), {}, "piotr does not read U")
    local pushes = mocks.sent(ewa_connection)
    test.assert_eq(#pushes, 1)
    test.assert_deep_eq(pushes[1].body, {
        id = "U",
        new_id = "Ursula",
        token = game_data().tokens.U
    })

    ---@type Response
    local acknowledgement = {
        source = "s",
        id = "TokenChangedRp",
        body = {}
    }
    ewa_connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(acknowledgement)))
    app.update_event:trigger(0.016)
    test.assert_deep_eq(mocks.sent(ewa_connection), {}, "an acknowledgement is answered with nothing")
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
end)

server_case("a session that logged out or died is sent nothing", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local ewa_connection = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, "adam")
    mocks.request(piotr_connection, "LogoutRp", {})
    mocks.sent(piotr_connection)
    local ewa_out = ewa_connection:get_out_channel()
    lifetime.destroy(ewa_connection)
    local ewa_count = ewa_out:getCount()
    local response = update(server.side.connection, {
        id = "T",
        changes = {
            name = "Tilly"
        }
    })
    test.assert_true(response.success)
    test.assert_deep_eq(mocks.sent(piotr_connection), {})
    test.assert_eq(ewa_out:getCount(), ewa_count)
    lifetime.destroy(piotr_connection)
end)

test.suite("UpdateTokenRp, the client")

---@param name string
---@param grants string[]
---@param fn fun(client: GameClient)
local function client_case(name, grants, fn)
    test.case(name, function()
        local client = game_client.enter(grants)
        local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
        notifications.messages = {}
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

---@param client GameClient
---@param id string
---@param dx number In page meters
local function drag(client, id, dx)
    game_client.select(client, {
        id
    })
    local page = client.game_screen:get_page()
    local coordinates = page:get_page_coordinates()
    local tx, ty = game_client.find_token(client, id):get_position()
    local x0, y0 = coordinates:transform_to_global(tx, ty)
    local x1, y1 = coordinates:transform_to_global(tx + dx, ty)
    page:on_pointer_down(x0, y0, Consts.PAGE_DRAG_TOKEN_BUTTON)
    page:on_pointer_move(x1, y1)
    page:on_pointer_up(x1, y1, Consts.PAGE_DRAG_TOKEN_BUTTON)
end

client_case("a refused move is notified and the token restored from the response, on the page and in the data", {
    "read",
    "write:tokens/@owned"
}, function(client)
    local token = game_client.find_token(client, "Bilbosza")
    drag(client, "Bilbosza", 3)
    local request = game_client.pop_request(client, "UpdateTokenRp") --[[@as UpdateTokenRequest]]
    test.assert_eq(request.id, "Bilbosza")
    local x, y = token:get_position()
    test.assert_near(x, 5, 1e-9)
    test.assert_near(y, 2, 1e-9)
    game_client.answer(client, "UpdateTokenRp", {
        success = false,
        error = "Not allowed to change the token \"Bilbosza\"",
        id = "Bilbosza",
        token = game_client.game_data().tokens.Bilbosza
    })
    test.assert_deep_eq(notified(client), {
        "Not allowed to change the token \"Bilbosza\""
    })
    test.assert_deep_eq({
        token:get_position()
    }, {
        2,
        2
    })
    test.assert_deep_eq(assert(client.app.data).tokens.Bilbosza.position, {
        2,
        2
    })
end)

client_case("a refused rename is renamed back: the token, the data, the page's list, the set, and the panel shows the id again", {
    "read",
    "write:tokens/Bilbosza"
}, function(client)
    game_client.select(client, {
        "Bilbosza"
    })
    local token = game_client.find_token(client, "Bilbosza")
    local panel = client.game_screen:get_token_panel()
    ---@diagnostic disable-next-line: invisible
    assert(panel._id_input):set_text("Bilbo")
    ---@diagnostic disable-next-line: invisible
    panel:_apply()
    test.assert_eq(token:get_id(), "Bilbo", "renamed at once")
    local request = game_client.pop_request(client, "UpdateTokenRp") --[[@as UpdateTokenRequest]]
    test.assert_eq(request.id, "Bilbosza")
    test.assert_eq(request.new_id, "Bilbo")
    game_client.answer(client, "UpdateTokenRp", {
        success = false,
        error = "A token with the id \"Bilbo\" already exists",
        id = "Bilbosza",
        new_id = "Bilbo",
        token = game_client.game_data().tokens.Bilbosza
    })
    test.assert_deep_eq(notified(client), {
        "A token with the id \"Bilbo\" already exists"
    })
    local data = assert(client.app.data)
    test.assert_eq(token:get_id(), "Bilbosza")
    test.assert_eq(data.tokens.Bilbo, nil)
    test.assert_true(data.tokens.Bilbosza ~= nil)
    test.assert_deep_eq(client.game_screen:get_page():get_data().tokens, {
        "Bilbosza",
        "Smaug"
    })
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read",
        "write:tokens/Bilbosza"
    })
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(assert(panel._id_input):get_text(), "Bilbosza")
end)

client_case("a refusal answered after the game was left restores the data alone", {
    "read",
    "write:tokens/@owned"
}, function(client)
    drag(client, "Bilbosza", 3)
    game_client.pop_request(client, "UpdateTokenRp")
    client.session:leave_game()
    test.assert_eq(client.session:get_game_screen(), nil)
    game_client.answer(client, "UpdateTokenRp", {
        success = false,
        error = "Not allowed to change the token \"Bilbosza\"",
        id = "Bilbosza",
        token = game_client.game_data().tokens.Bilbosza
    })
    test.assert_deep_eq(notified(client), {
        "Not allowed to change the token \"Bilbosza\""
    })
    test.assert_deep_eq(assert(client.app.data).tokens.Bilbosza.position, {
        2,
        2
    })
end)

client_case("an accepted change the server holds as the client does changes nothing on the client", {
    "read",
    "write:tokens/@owned"
}, function(client)
    local token = game_client.find_token(client, "Bilbosza")
    drag(client, "Bilbosza", 3)
    game_client.pop_request(client, "UpdateTokenRp")
    local expected = game_client.game_data().tokens.Bilbosza
    expected.position = {
        5,
        2
    }
    game_client.answer(client, "UpdateTokenRp", {
        success = true,
        id = "Bilbosza",
        token = expected
    })
    test.assert_deep_eq(notified(client), {})
    local x = token:get_position()
    test.assert_near(x, 5, 1e-9)
end)

client_case("an accepted move the server holds elsewhere, a concurrent change, takes the server's entry on the page and in the data without a notification", {
    "read",
    "write:tokens/@owned"
}, function(client)
    local token = game_client.find_token(client, "Bilbosza")
    drag(client, "Bilbosza", 3)
    game_client.pop_request(client, "UpdateTokenRp")
    local expected = game_client.game_data().tokens.Bilbosza
    expected.position = {
        6,
        4
    }
    expected.name = "Bilbo Baggins"
    game_client.answer(client, "UpdateTokenRp", {
        success = true,
        id = "Bilbosza",
        token = expected
    })
    test.assert_deep_eq(notified(client), {})
    test.assert_deep_eq({
        token:get_position()
    }, {
        6,
        4
    })
    test.assert_deep_eq(assert(client.app.data).tokens.Bilbosza, expected)
    test.assert_eq(token:get_data().name, "Bilbo Baggins")
end)

client_case("an accepted rename takes the server's entry under the new id, where the client already holds the token", {
    "read",
    "write:tokens/Bilbosza"
}, function(client)
    game_client.select(client, {
        "Bilbosza"
    })
    local token = game_client.find_token(client, "Bilbosza")
    local panel = client.game_screen:get_token_panel()
    ---@diagnostic disable-next-line: invisible
    assert(panel._id_input):set_text("Bilbo")
    ---@diagnostic disable-next-line: invisible
    panel:_apply()
    game_client.pop_request(client, "UpdateTokenRp")
    local expected = game_client.game_data().tokens.Bilbosza
    expected.diameter = 2
    game_client.answer(client, "UpdateTokenRp", {
        success = true,
        id = "Bilbosza",
        new_id = "Bilbo",
        token = expected
    })
    test.assert_deep_eq(notified(client), {})
    local data = assert(client.app.data)
    test.assert_eq(token:get_id(), "Bilbo")
    test.assert_eq(data.tokens.Bilbosza, nil)
    test.assert_deep_eq(data.tokens.Bilbo, expected)
    test.assert_eq(token:get_data().diameter, 2)
    test.assert_deep_eq(client.game_screen:get_page():get_data().tokens, {
        "Bilbo",
        "Smaug"
    })
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read",
        "write:tokens/Bilbo"
    })
end)

client_case("an accepted change answered without the token, which the session may not read, applies nothing", {
    "read",
    "write:tokens/@owned"
}, function(client)
    local token = game_client.find_token(client, "Bilbosza")
    drag(client, "Bilbosza", 3)
    game_client.pop_request(client, "UpdateTokenRp")
    local before = table.deep_copy(assert(client.app.data).tokens)
    game_client.answer(client, "UpdateTokenRp", {
        success = true,
        id = "Bilbosza"
    })
    test.assert_deep_eq(notified(client), {})
    test.assert_deep_eq(assert(client.app.data).tokens, before)
    local x = token:get_position()
    test.assert_near(x, 5, 1e-9)
end)

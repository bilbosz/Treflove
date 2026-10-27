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
                    "T"
                }
            },
            Q = {
                name = "Q",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {}
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
            notes = {
                title = "Notes",
                type = "string"
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
            }
        }
    }
end

---@return TokenData A valid new token
local function new_token()
    return {
        name = "Gandalf",
        diameter = 1,
        avatar = "token/t.png",
        position = {
            3,
            4
        }
    }
end

---@param changes table<string, TokenDataValue|false> Over `new_token()`; `false` removes the key
---@return TokenData
local function token_with(changes)
    ---@type table<string, TokenDataValue|nil>
    local token = new_token()
    for key, value in pairs(changes) do
        if value == false then
            token[key] = nil
        else
            token[key] = value
        end
    end
    return token --[[@as TokenData]]
end

---@class TestCreateTokenServer
---@field side TestServerSide
---@field files table<string, string> The fake file system, `SAVE` among them

---@param name string
---@param fn fun(server: TestCreateTokenServer)
local function server_case(name, fn)
    test.case(name, function()
        ---@type table<string, string>
        local files = {
            ["s/games/g/assets/world/w.png"] = "W",
            ["s/games/g/assets/token/t.png"] = "T"
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

---@param server TestCreateTokenServer
---@return GameData The server's own
local function server_data(server)
    return assert(assert(server.side.server.games):get(mocks.GAME_ID)):get_data()
end

---@param server TestCreateTokenServer
---@return GameData What `save.lua` holds
local function saved(server)
    return table.from_string(assert(server.files[SAVE])) --[[@as GameData]]
end

---@param connection Connection
---@param request CreateTokenRequest
---@return CreateTokenResponse
local function create(connection, request)
    return mocks.request(connection, "CreateTokenRp", request) --[[@as CreateTokenResponse]]
end

test.suite("CreateTokenRp")

server_case("a master creates a token: the data, the page's list, the save, the response, and a push to the sessions that read it", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local ewa_connection = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(ewa_connection)
    local token = new_token()
    token.notes = "A wizard"
    local response = create(server.side.connection, {
        id = "Gandalf",
        page = "P",
        token = token
    })
    test.assert_deep_eq(response, {
        success = true,
        id = "Gandalf",
        page = "P",
        token = token
    })
    test.assert_eq(server.side.connection:get_out_channel():getCount(), 0, "the response only, popped by the request")
    for _, data in ipairs({
        server_data(server),
        saved(server)
    }) do
        test.assert_deep_eq(data.tokens.Gandalf, token)
        test.assert_eq(data.tokens.Gandalf.owners, nil, "a created token belongs to the game")
        test.assert_deep_eq(data.pages.P.tokens, {
            "T",
            "Gandalf"
        })
        test.assert_deep_eq(data.pages.Q.tokens, {})
        test.assert_deep_eq(data.tokens.T, game_data().tokens.T)
    end
    local pushes = mocks.sent(ewa_connection)
    test.assert_eq(#pushes, 1)
    test.assert_eq(pushes[1].source, "s")
    test.assert_eq(pushes[1].id, "TokenCreatedRp")
    test.assert_deep_eq(pushes[1].body, {
        id = "Gandalf",
        page = "P",
        token = token
    })
    test.assert_deep_eq(mocks.sent(piotr_connection), {}, "piotr reads the tokens he owns, and nobody owns this one")
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
end)

server_case("a token is created on the page requested, with the position copied", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = create(server.side.connection, {
        id = "Q1",
        page = "Q",
        token = new_token()
    })
    test.assert_true(response.success)
    local data = server_data(server)
    test.assert_deep_eq(data.pages.Q.tokens, {
        "Q1"
    })
    test.assert_deep_eq(data.pages.P.tokens, {
        "T"
    })
    test.assert_deep_eq(data.tokens.Q1.position, {
        3,
        4
    })
end)

server_case("a session not in a game is refused, logged in or not", function(server)
    ---@type CreateTokenRequest
    local request = {
        id = "Gandalf",
        page = "P",
        token = new_token()
    }
    local response = create(server.side.connection, request)
    test.assert_deep_eq(response, {
        success = false,
        error = "Not in a game",
        id = "Gandalf",
        page = "P"
    })
    mocks.log_in(server.side.connection, "adam")
    response = create(server.side.connection, request)
    test.assert_eq(response.error, "Not in a game")
end)

---@param server TestCreateTokenServer
---@param login string
---@param cases {request: CreateTokenRequest, error: string}[]
local function assert_refusals(server, login, cases)
    local ewa_connection = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, login)
    mocks.sent(ewa_connection)
    local before = server.files[SAVE]
    for _, case in ipairs(cases) do
        local response = create(server.side.connection, case.request)
        test.assert_false(response.success, case.error)
        test.assert_eq(response.error, case.error)
        test.assert_eq(response.id, case.request.id)
        test.assert_eq(response.page, case.request.page)
        test.assert_eq(response.token, nil)
    end
    test.assert_deep_eq(server_data(server), game_data(), "nothing applied")
    test.assert_eq(server.files[SAVE], before, "nothing saved")
    test.assert_deep_eq(mocks.sent(ewa_connection), {}, "nothing pushed")
    lifetime.destroy(ewa_connection)
end

server_case("a player without write on the whole kind is refused before anything else, though they write the tokens they own", function(server)
    assert_refusals(server, "piotr", {
        {
            request = {
                id = "Gandalf",
                page = "P",
                token = new_token()
            },
            error = "Not allowed to create a token"
        },
        {
            request = {
                id = "",
                page = "Nowhere",
                token = token_with({
                    name = false
                })
            },
            error = "Not allowed to create a token"
        }
    })
end)

server_case("an id the game refuses is refused with its reason, before the page", function(server)
    assert_refusals(server, "adam", {
        {
            request = {
                id = "",
                page = "Nowhere",
                token = new_token()
            },
            error = "An id must not be empty"
        },
        {
            request = {
                id = "@owned",
                page = "P",
                token = new_token()
            },
            error = "An id must not start with \"@\""
        },
        {
            request = {
                id = "T",
                page = "P",
                token = new_token()
            },
            error = "A token with the id \"T\" already exists"
        }
    })
end)

server_case("a page the game lacks is refused, before the entry", function(server)
    assert_refusals(server, "adam", {
        {
            request = {
                id = "Gandalf",
                page = "Nowhere",
                token = token_with({
                    name = false
                })
            },
            error = "No page \"Nowhere\""
        }
    })
end)

server_case("an entry that is not a table or lacks a required field is refused, naming the first in the order name, diameter, avatar, position", function(server)
    ---@type {request: CreateTokenRequest, error: string}[]
    local cases = {}
    ---@type {token: TokenData, missing: string}[]
    local entries = {
        {
            token = token_with({
                name = false,
                diameter = false
            }),
            missing = "name"
        },
        {
            token = token_with({
                name = 5,
                owners = {
                    "adam"
                }
            }),
            missing = "name"
        },
        {
            token = token_with({
                diameter = false,
                avatar = false
            }),
            missing = "diameter"
        },
        {
            token = token_with({
                diameter = 0
            }),
            missing = "diameter"
        },
        {
            token = token_with({
                diameter = "big"
            }),
            missing = "diameter"
        },
        {
            token = token_with({
                avatar = false
            }),
            missing = "avatar"
        },
        {
            token = token_with({
                position = false
            }),
            missing = "position"
        },
        {
            token = token_with({
                position = {
                    1
                }
            }),
            missing = "position"
        },
        {
            token = token_with({
                position = {
                    1,
                    "2"
                }
            }),
            missing = "position"
        }
    }
    for _, entry in ipairs(entries) do
        table.insert(cases, {
            request = {
                id = "Gandalf",
                page = "P",
                token = entry.token
            },
            error = string.format("A new token needs %q", entry.missing)
        })
    end
    assert_refusals(server, "adam", cases)
end)

server_case("an entry that is not a table is refused as one without a name", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = mocks.request(server.side.connection, "CreateTokenRp", {
        id = "Gandalf",
        page = "P",
        token = "Gandalf"
    }) --[[@as CreateTokenResponse]]
    test.assert_false(response.success)
    test.assert_eq(response.error, "A new token needs \"name\"")
    test.assert_deep_eq(server_data(server), game_data())
end)

server_case("owners, an unknown key, an array property or a value of the wrong type is refused, before the avatar", function(server)
    ---@type {request: CreateTokenRequest, error: string}[]
    local cases = {}
    ---@type table<string, TokenDataValue>
    local bad = {
        owners = {
            "adam"
        },
        speed = 3,
        notes = 5
    }
    for key, value in pairs(bad) do
        table.insert(cases, {
            request = {
                id = "Gandalf",
                page = "P",
                token = token_with({
                    avatar = "token/missing.png",
                    [key] = value
                })
            },
            error = string.format("Cannot set %q of a new token", key)
        })
    end
    assert_refusals(server, "adam", cases)
end)

server_case("an avatar the game's store has no file for is refused", function(server)
    ---@type {request: CreateTokenRequest, error: string}[]
    local cases = {}
    for _, avatar in ipairs({
        "token/missing.png",
        "token",
        "../save.lua",
        ""
    }) do
        table.insert(cases, {
            request = {
                id = "Gandalf",
                page = "P",
                token = token_with({
                    avatar = avatar
                })
            },
            error = string.format("No asset %q", avatar)
        })
    end
    assert_refusals(server, "adam", cases)
end)

server_case("a request from the server's peer for the push is logged and acknowledged with nothing", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = mocks.request(server.side.connection, "TokenCreatedRp", {
        id = "Gandalf",
        page = "P",
        token = new_token()
    })
    test.assert_deep_eq(response, {})
    test.assert_deep_eq(server.side.server.logs[#server.side.server.logs], {
        "TokenCreatedRp is the server's to send: a request from the client ignored"
    })
    test.assert_eq(server_data(server).tokens.Gandalf, nil)
end)

test.suite("CreateTokenRp, the client")

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

---@return TokenData A new token of the client's game, its avatar in the client's store
local function client_token()
    return {
        name = "Gandalf",
        diameter = 1,
        avatar = "token/s.png",
        position = {
            3,
            4
        }
    }
end

client_case("create_token sends the token on the shown page; the answer adds it to the data, the page's list and the page, then runs the callback", {
    "read",
    "write"
}, function(client)
    notified(client)
    local page = client.game_screen:get_page()
    ---@type CreateTokenResponse[]
    local answers = {}
    ---@type (Token|nil)[]
    local shown = {}
    client.session:create_token("Gandalf", client_token(), function(response)
        table.insert(answers, response)
        table.insert(shown, page:try_find_token("Gandalf"))
    end)
    local request = game_client.pop_request(client, "CreateTokenRp") --[[@as CreateTokenRequest]]
    test.assert_deep_eq(request, {
        id = "Gandalf",
        page = "P",
        token = client_token()
    })
    local data = assert(client.app.data)
    test.assert_eq(data.tokens.Gandalf, nil, "nothing before the answer")
    test.assert_eq(page:try_find_token("Gandalf"), nil)
    ---@type CreateTokenResponse
    local response = {
        success = true,
        id = "Gandalf",
        page = "P",
        token = client_token()
    }
    game_client.answer(client, "CreateTokenRp", response)
    test.assert_deep_eq(data.tokens.Gandalf, client_token())
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza",
        "Smaug",
        "Gandalf"
    })
    local token = assert(page:try_find_token("Gandalf"))
    test.assert_eq(token:get_data(), data.tokens.Gandalf)
    test.assert_deep_eq({
        token:get_position()
    }, {
        3,
        4
    })
    test.assert_deep_eq(answers, {
        response
    })
    test.assert_eq(shown[1], token, "the callback runs once the token is in")
    test.assert_deep_eq(notified(client), {})
end)

client_case("a refusal is notified, nothing is applied, and the callback runs with it", {
    "read"
}, function(client)
    notified(client)
    ---@type CreateTokenResponse[]
    local answers = {}
    client.session:create_token("Gandalf", client_token(), function(response)
        table.insert(answers, response)
    end)
    game_client.pop_request(client, "CreateTokenRp")
    ---@type CreateTokenResponse
    local response = {
        success = false,
        error = "Not allowed to create a token",
        id = "Gandalf",
        page = "P"
    }
    game_client.answer(client, "CreateTokenRp", response)
    test.assert_deep_eq(notified(client), {
        "Not allowed to create a token"
    })
    test.assert_deep_eq(assert(client.app.data).tokens, game_client.game_data().tokens)
    test.assert_eq(#client.game_screen:get_page():get_tokens(), 2)
    test.assert_deep_eq(answers, {
        response
    })
end)

client_case("a success without the entry, for a creator who may not read the token, applies nothing; the callback is optional", {
    "read:game",
    "read:pages",
    "write:tokens"
}, function(client)
    client.session:create_token("Gandalf", client_token())
    game_client.pop_request(client, "CreateTokenRp")
    game_client.answer(client, "CreateTokenRp", {
        success = true,
        id = "Gandalf",
        page = "P"
    })
    test.assert_eq(assert(client.app.data).tokens.Gandalf, nil)
    test.assert_eq(client.game_screen:get_page():try_find_token("Gandalf"), nil)
end)

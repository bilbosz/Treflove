local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")

local SAVE = "s/games/g/save.lua"

---@class TestCreateEntryServer
---@field side TestServerSide
---@field files table<string, string> The fake file system, `SAVE` among them

---@param name string
---@param fn fun(server: TestCreateEntryServer)
local function server_case(name, fn)
    test.case(name, function()
        ---@type table<string, string>
        local files = {
            ["s/games/g/assets/world/w.png"] = "W",
            ["s/games/g/assets/world/n.png"] = "N"
        }
        local side = mocks.make_server_session(mocks.entries_game_data, files)
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

---@param server TestCreateEntryServer
---@return GameData What `save.lua` holds
local function saved(server)
    return table.from_string(assert(server.files[SAVE])) --[[@as GameData]]
end

---@param connection Connection
---@param request CreateEntryRequest
---@return CreateEntryResponse
local function create(connection, request)
    return mocks.request(connection, "CreateEntryRp", request) --[[@as CreateEntryResponse]]
end

---@return PageData
local function new_page()
    return {
        name = "Cellar",
        width = 10,
        pixel_per_meter = 4,
        image = "world/n.png",
        tokens = {}
    }
end

test.suite("CreateEntryRp")

server_case("a master creates a page: the data, the save, the response, and a push to the other sessions that read it", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local ewa_connection = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(ewa_connection)
    local response = create(server.side.connection, {
        kind = "pages",
        id = "C",
        entry = {
            name = "Cellar",
            width = 10,
            pixel_per_meter = 4,
            image = "world/n.png"
        }
    })
    test.assert_true(response.success)
    test.assert_eq(response.kind, "pages")
    test.assert_eq(response.id, "C")
    test.assert_deep_eq(response.entry, new_page())
    local game = assert(assert(server.side.server.games):get(mocks.GAME_ID))
    test.assert_deep_eq(game:get_data().pages.C, new_page())
    test.assert_deep_eq(saved(server).pages.C, new_page())
    test.assert_eq(server.side.connection:get_out_channel():getCount(), 0, "the response only")
    test.assert_deep_eq(mocks.sent(piotr_connection), {}, "piotr reads the page P only")
    local pushes = mocks.sent(ewa_connection)
    test.assert_eq(#pushes, 1)
    test.assert_eq(pushes[1].id, "EntryCreatedRp")
    test.assert_deep_eq(pushes[1].body, {
        kind = "pages",
        id = "C",
        entry = new_page()
    })
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
end)

server_case("a group created gets no grants unless given, and the sessions of players in it are sent their grants", function(server)
    local olga_connection, olga = mocks.join_another("olga")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(olga_connection)
    local response = create(server.side.connection, {
        kind = "groups",
        id = "spare",
        entry = {
            title = "Spare"
        }
    })
    test.assert_true(response.success)
    test.assert_deep_eq(saved(server).groups.spare, {
        title = "Spare",
        permissions = {}
    })
    test.assert_deep_eq(mocks.sent(olga_connection), {}, "olga reads nothing and her grants are the same")
    response = create(server.side.connection, {
        kind = "groups",
        id = "guests",
        entry = {
            title = "Guests",
            permissions = {
                "read:game"
            }
        }
    })
    test.assert_true(response.success)
    test.assert_deep_eq(olga:get_permissions():get_grants(), {
        "read:game"
    })
    local pushes = mocks.sent(olga_connection)
    test.assert_eq(#pushes, 1)
    test.assert_eq(pushes[1].id, "GrantsChangedRp")
    test.assert_deep_eq(pushes[1].body, {
        permissions = {
            "read:game"
        }
    })
    lifetime.destroy(olga_connection)
end)

server_case("a session not in a game, an unknown kind, a kind never created, a session without write on the whole kind, an id or an entry the entries refuse are refused, nothing applied",
            function(server)
    local request = {
        kind = "pages",
        id = "C",
        entry = new_page()
    }
    local response = create(server.side.connection, request)
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not in a game")
    mocks.join_game(server.side.connection, "piotr")
    test.assert_eq(create(server.side.connection, request).error, "Not allowed to create a page", "piotr writes the page P only")
    mocks.request(server.side.connection, "LogoutRp", {})
    mocks.join_game(server.side.connection, "adam")
    local before = server.files[SAVE]
    ---@type {request: CreateEntryRequest, error: string}[]
    local refused = {
        {
            request = {
                kind = "players",
                id = "frodo",
                entry = {
                    group = "player"
                }
            },
            error = "Players cannot be created"
        },
        {
            request = {
                kind = "game",
                id = "other",
                entry = {
                    page = "P"
                }
            },
            error = "The game cannot be created"
        },
        {
            request = {
                kind = "pages",
                id = "Q",
                entry = new_page()
            },
            error = "A page with the id \"Q\" already exists"
        },
        {
            request = {
                kind = "pages",
                id = "@C",
                entry = new_page()
            },
            error = "An id must not start with \"@\""
        },
        {
            request = {
                kind = "pages",
                id = "C",
                entry = {
                    name = "Cellar",
                    image = "world/n.png"
                }
            },
            error = "A new page needs \"width\""
        },
        {
            request = {
                kind = "pages",
                id = "C",
                entry = {
                    name = "Cellar",
                    width = 10,
                    pixel_per_meter = 4,
                    image = "world/none.png"
                }
            },
            error = "No asset \"world/none.png\""
        },
        {
            request = {
                kind = "token_properties",
                id = "speed",
                entry = {
                    title = "Speed",
                    type = "color"
                }
            },
            error = "Type must be one of string, number, image, array"
        }
    }
    response = mocks.request(server.side.connection, "CreateEntryRp", {
        kind = "tokens",
        id = "X",
        entry = new_page()
    }) --[[@as CreateEntryResponse]]
    test.assert_eq(response.error, "No kind \"tokens\"")
    for _, case in ipairs(refused) do
        response = create(server.side.connection, case.request)
        test.assert_false(response.success, case.error)
        test.assert_eq(response.error, case.error)
        test.assert_eq(response.kind, case.request.kind)
        test.assert_eq(response.id, case.request.id)
        test.assert_eq(response.entry, nil)
    end
    test.assert_eq(server.files[SAVE], before)
end)

server_case("a request from the server's peer for the push is logged and acknowledged with nothing", function(server)
    mocks.join_game(server.side.connection, "adam")
    local before = server.files[SAVE]
    local response = mocks.request(server.side.connection, "EntryCreatedRp", {
        kind = "pages",
        id = "C",
        entry = new_page()
    })
    test.assert_deep_eq(response, {})
    test.assert_deep_eq(server.side.server.logs[#server.side.server.logs], {
        "EntryCreatedRp is the server's to send: a request from the client ignored"
    })
    test.assert_eq(server.files[SAVE], before)
end)

test.suite("CreateEntryRp, the client")

---@param name string
---@param fn fun(side: TestClientSide, screen: TestGameScreen)
local function client_case(name, fn)
    test.case(name, function()
        local side = mocks.make_client_session({})
        mocks.join_client_game(side, "adam", mocks.entries_game_data(), {
            "read",
            "write"
        })
        local screen = mocks.make_game_screen()
        ---@diagnostic disable-next-line: invisible
        side.session._game_screen = screen
        ---@type boolean, any
        local ok, err = pcall(fn, side, screen)
        mocks.finish_client_session(side)
        if not ok then
            error(err, 0)
        end
    end)
end

client_case("create_entry sends the entry; the answer adds it to the data, tells the game screen, then runs the callback", function(side, screen)
    ---@type CreateEntryResponse[]
    local answers = {}
    side.session:create_entry("pages", "C", {
        name = "Cellar",
        width = 10,
        pixel_per_meter = 4,
        image = "world/n.png"
    }, function(response)
        test.assert_deep_eq(screen.calls, {
            "on_entries_change pages C"
        }, "applied first")
        table.insert(answers, response)
    end)
    local sent = mocks.sent(side.connection)
    test.assert_eq(#sent, 1)
    test.assert_eq(sent[1].id, "CreateEntryRp")
    test.assert_deep_eq(sent[1].body, {
        kind = "pages",
        id = "C",
        entry = {
            name = "Cellar",
            width = 10,
            pixel_per_meter = 4,
            image = "world/n.png"
        }
    })
    test.assert_eq(assert(side.client.data).pages.C, nil, "nothing before the answer")
    mocks.answer(side.connection, "CreateEntryRp", {
        success = true,
        kind = "pages",
        id = "C",
        entry = new_page()
    })
    test.assert_deep_eq(assert(side.client.data).pages.C, new_page())
    test.assert_eq(#answers, 1)
    test.assert_true(answers[1].success)
end)

client_case("a refusal is notified, nothing is applied, and the callback runs with it", function(side, screen)
    ---@type CreateEntryResponse[]
    local answers = {}
    side.session:create_entry("groups", "master", {
        title = "Again"
    }, function(response)
        table.insert(answers, response)
    end)
    mocks.answer(side.connection, "CreateEntryRp", {
        success = false,
        error = "A group with the id \"master\" already exists",
        kind = "groups",
        id = "master"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "A group with the id \"master\" already exists"
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
    test.assert_eq(#answers, 1)
    test.assert_false(answers[1].success)
end)

client_case("a success without the entry, for a creator who may not read it, applies nothing; the callback is optional", function(side, screen)
    side.session:create_entry("pages", "C", new_page())
    mocks.answer(side.connection, "CreateEntryRp", {
        success = true,
        kind = "pages",
        id = "C"
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

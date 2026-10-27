local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local entries = require("game.entry.entries")
local permissions = require("game.permissions")

local SAVE = "s/games/g/save.lua"

---@class TestUpdateEntryServer
---@field side TestServerSide
---@field files table<string, string> The fake file system, `SAVE` among them

---@param name string
---@param fn fun(server: TestUpdateEntryServer)
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

---@param server TestUpdateEntryServer
---@return GameData The server's own
local function server_data(server)
    return assert(assert(server.side.server.games):get(mocks.GAME_ID)):get_data()
end

---@param server TestUpdateEntryServer
---@return GameData What `save.lua` holds
local function saved(server)
    return table.from_string(assert(server.files[SAVE])) --[[@as GameData]]
end

---@param connection Connection
---@param request UpdateEntryRequest
---@return UpdateEntryResponse
local function update(connection, request)
    return mocks.request(connection, "UpdateEntryRp", request) --[[@as UpdateEntryResponse]]
end

---@param connection Connection
---@return string[] The ids of what the connection sent since the last call
local function sent_ids(connection)
    ---@type string[]
    local ids = {}
    for _, request in ipairs(mocks.sent(connection)) do
        table.insert(ids, request.id)
    end
    return ids
end

test.suite("UpdateEntryRp")

server_case("a master changes a page: the data, the save, the response's entry, and a push to the other sessions that read it", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local olga_connection = mocks.join_another("olga")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(olga_connection)
    local response = update(server.side.connection, {
        kind = "pages",
        id = "P",
        changes = {
            name = "Pastures",
            width = 12,
            image = "world/n.png"
        }
    })
    local expected = mocks.entries_game_data().pages.P
    expected.name = "Pastures"
    expected.width = 12
    expected.image = "world/n.png"
    test.assert_true(response.success)
    test.assert_eq(response.kind, "pages")
    test.assert_eq(response.id, "P")
    test.assert_eq(response.new_id, nil)
    test.assert_deep_eq(response.entry, expected)
    test.assert_deep_eq(server_data(server).pages.P, expected)
    test.assert_deep_eq(saved(server).pages.P, expected)
    test.assert_deep_eq(saved(server).pages.Q, mocks.entries_game_data().pages.Q, "the other page as it was")
    test.assert_eq(server.side.connection:get_out_channel():getCount(), 0, "the response only, popped by the request")
    local pushes = mocks.sent(piotr_connection)
    test.assert_eq(#pushes, 1)
    test.assert_eq(pushes[1].source, "s")
    test.assert_eq(pushes[1].id, "EntryChangedRp")
    test.assert_deep_eq(pushes[1].body, {
        kind = "pages",
        id = "P",
        entry = expected
    })
    test.assert_deep_eq(mocks.sent(olga_connection), {}, "olga reads nothing")
    lifetime.destroy(piotr_connection)
    lifetime.destroy(olga_connection)
end)

server_case("a rename renames the key, the shown page and the grants on it; the sessions whose grants changed are sent them", function(server)
    local piotr_connection, piotr = mocks.join_another("piotr")
    local ewa_connection = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(ewa_connection)
    local response = update(server.side.connection, {
        kind = "pages",
        id = "P",
        new_id = "R",
        changes = {
            name = "Ruins"
        }
    })
    local expected = mocks.entries_game_data().pages.P
    expected.name = "Ruins"
    test.assert_true(response.success)
    test.assert_eq(response.id, "P")
    test.assert_eq(response.new_id, "R")
    test.assert_deep_eq(response.entry, expected)
    for _, data in ipairs({
        server_data(server),
        saved(server)
    }) do
        test.assert_eq(data.pages.P, nil)
        test.assert_deep_eq(data.pages.R, expected)
        test.assert_eq(data.game.page, "R")
        test.assert_deep_eq(data.groups.player.permissions, {
            "read:game",
            "read:pages/R",
            "read:groups",
            "read:players"
        })
        test.assert_deep_eq(data.players.piotr.permissions, {
            "write:pages/R"
        })
    end
    local grants = {
        "read:game",
        "read:pages/R",
        "read:groups",
        "read:players",
        "write:pages/R"
    }
    test.assert_deep_eq(piotr:get_permissions():get_grants(), grants)
    test.assert_true(piotr:is_allowed(permissions.Action.WRITE, permissions.Kind.PAGES, "R"))
    local pushes = mocks.sent(piotr_connection)
    test.assert_eq(#pushes, 2)
    test.assert_eq(pushes[1].id, "EntryChangedRp")
    test.assert_deep_eq(pushes[1].body, {
        kind = "pages",
        id = "P",
        new_id = "R",
        entry = expected
    })
    test.assert_eq(pushes[2].id, "GrantsChangedRp")
    test.assert_deep_eq(pushes[2].body, {
        permissions = grants
    })
    test.assert_deep_eq(sent_ids(ewa_connection), {
        "EntryChangedRp"
    }, "her grants name no P")
    test.assert_eq(server.side.connection:get_out_channel():getCount(), 0, "the master's grants did not change")
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
end)

server_case("the game's page is changed with write on the game and pushed to every session that reads the game", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local olga_connection = mocks.join_another("olga")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(olga_connection)
    local response = update(server.side.connection, {
        kind = "game",
        id = entries.GAME_ID,
        changes = {
            page = "Q"
        }
    })
    test.assert_true(response.success)
    test.assert_deep_eq(response.entry, {
        page = "Q"
    })
    test.assert_eq(saved(server).game.page, "Q")
    local pushes = mocks.sent(piotr_connection)
    test.assert_eq(#pushes, 1)
    test.assert_deep_eq(pushes[1].body, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "Q"
        }
    })
    test.assert_deep_eq(mocks.sent(olga_connection), {})
    lifetime.destroy(piotr_connection)
    lifetime.destroy(olga_connection)
end)

server_case("a group's grants changed are pushed to the sessions in it, the change to those that read the group", function(server)
    local piotr_connection, piotr = mocks.join_another("piotr")
    local ewa_connection = mocks.join_another("ewa")
    local olga_connection = mocks.join_another("olga")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(ewa_connection)
    mocks.sent(olga_connection)
    local response = update(server.side.connection, {
        kind = "groups",
        id = "player",
        changes = {
            title = "Players",
            permissions = {
                "read",
                "write:tokens"
            }
        }
    })
    test.assert_true(response.success)
    test.assert_deep_eq(saved(server).groups.player, {
        title = "Players",
        permissions = {
            "read",
            "write:tokens"
        }
    })
    test.assert_true(piotr:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS))
    local pushes = mocks.sent(piotr_connection)
    test.assert_deep_eq({
        pushes[1].id,
        pushes[2].id
    }, {
        "EntryChangedRp",
        "GrantsChangedRp"
    })
    test.assert_eq(#pushes, 2)
    test.assert_deep_eq(pushes[2].body, {
        permissions = {
            "read",
            "write:tokens",
            "write:pages/P"
        }
    })
    test.assert_deep_eq(sent_ids(ewa_connection), {
        "EntryChangedRp"
    })
    test.assert_deep_eq(sent_ids(olga_connection), {})
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
    lifetime.destroy(olga_connection)
end)

server_case("a requester whose own grants change is sent them too, before its response", function(server)
    mocks.join_game(server.side.connection, "adam")
    mocks.deliver(server.side.connection, "UpdateEntryRp", {
        kind = "players",
        id = "adam",
        changes = {
            permissions = {
                "view:pages/P"
            }
        }
    })
    local sent = mocks.sent(server.side.connection)
    test.assert_eq(#sent, 2)
    test.assert_eq(sent[1].id, "GrantsChangedRp")
    test.assert_deep_eq(sent[1].body, {
        permissions = {
            "read",
            "write",
            "view:pages/P"
        }
    })
    test.assert_eq(sent[2].id, "UpdateEntryRp")
    test.assert_true((sent[2].body --[[@as UpdateEntryResponse]] ).success)
    test.assert_deep_eq(saved(server).players.adam, {
        group = "master",
        permissions = {
            "view:pages/P"
        }
    })
end)

server_case("a token property is renamed in every token; its type is not changed while a token holds it", function(server)
    mocks.join_game(server.side.connection, "adam")
    local response = update(server.side.connection, {
        kind = "token_properties",
        id = "hp",
        changes = {
            type = "string"
        }
    })
    test.assert_false(response.success)
    test.assert_eq(response.error, "The type of \"hp\" cannot change while a token holds it")
    test.assert_deep_eq(response.entry, mocks.entries_game_data().token_properties.hp)
    response = update(server.side.connection, {
        kind = "token_properties",
        id = "hp",
        new_id = "health",
        changes = {
            title = "Health"
        }
    })
    test.assert_true(response.success)
    test.assert_deep_eq(saved(server).token_properties.health, {
        title = "Health",
        type = "number"
    })
    test.assert_eq(saved(server).tokens.T.health, 3)
    test.assert_eq(saved(server).tokens.T.hp, nil)
end)

server_case("a session not in a game, an unknown kind or id, a session without write and a change or rename the entries refuse are refused, nothing applied", function(server)
    local request = {
        kind = "pages",
        id = "P",
        changes = {
            name = "X"
        }
    }
    local response = update(server.side.connection, request)
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not in a game")
    test.assert_eq(response.entry, nil)
    mocks.join_game(server.side.connection, "piotr")
    local before = server.files[SAVE]
    local page = mocks.entries_game_data().pages.P
    ---@type {request: UpdateEntryRequest, error: string, entry: EntryData|nil}[]
    local refused = {
        {
            request = {
                kind = "pages",
                id = "Z",
                changes = {}
            },
            error = "No page with the id \"Z\""
        },
        {
            request = {
                kind = "pages",
                id = "Q",
                changes = {
                    name = "Mine"
                }
            },
            error = "Not allowed to change the page \"Q\""
        },
        {
            request = {
                kind = "game",
                id = entries.GAME_ID,
                changes = {
                    page = "Q"
                }
            },
            error = "Not allowed to change the game",
            entry = {
                page = "P"
            }
        },
        {
            request = {
                kind = "pages",
                id = "P",
                new_id = "Q",
                changes = {}
            },
            error = "A page with the id \"Q\" already exists",
            entry = page
        },
        {
            request = {
                kind = "pages",
                id = "P",
                changes = {
                    tokens = {}
                }
            },
            error = "Cannot change \"tokens\" of the page \"P\"",
            entry = page
        },
        {
            request = {
                kind = "pages",
                id = "P",
                changes = {
                    name = "Applied?",
                    image = "world/x.png"
                }
            },
            error = "No asset \"world/x.png\"",
            entry = page
        }
    }
    response = mocks.request(server.side.connection, "UpdateEntryRp", {
        kind = "tokens",
        id = "T",
        changes = {}
    }) --[[@as UpdateEntryResponse]]
    test.assert_eq(response.error, "No kind \"tokens\"")
    for _, case in ipairs(refused) do
        response = update(server.side.connection, case.request)
        test.assert_false(response.success, case.error)
        test.assert_eq(response.error, case.error)
        test.assert_eq(response.kind, case.request.kind)
        test.assert_eq(response.id, case.request.id)
        test.assert_eq(response.new_id, case.request.new_id)
        test.assert_deep_eq(response.entry, case.entry, case.error)
    end
    test.assert_deep_eq(server_data(server), saved(server))
    test.assert_eq(server.files[SAVE], before)
end)

test.suite("UpdateEntryRp, the client")

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

---@param side TestClientSide
---@return UpdateEntryRp
local function rp_of(side)
    ---@diagnostic disable-next-line: invisible
    return side.session._update_entry_rp
end

client_case("update_entry sends the change and applies nothing before the answer", function(side, screen)
    side.session:update_entry("pages", "P", {
        name = "Ruins"
    }, "R")
    local sent = mocks.sent(side.connection)
    test.assert_eq(#sent, 1)
    test.assert_eq(sent[1].id, "UpdateEntryRp")
    test.assert_deep_eq(sent[1].body, {
        kind = "pages",
        id = "P",
        new_id = "R",
        changes = {
            name = "Ruins"
        }
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

client_case("an accepted change applies the server's entry under the new id and tells the game screen", function(side, screen)
    local entry = mocks.entries_game_data().pages.P
    entry.name = "Ruins"
    entry.tokens = {}
    rp_of(side):receive_response({
        success = true,
        kind = "pages",
        id = "P",
        new_id = "R",
        entry = entry
    })
    local data = assert(side.client.data)
    test.assert_eq(data.pages.P, nil)
    test.assert_eq(data.pages.R.name, "Ruins")
    test.assert_deep_eq(data.pages.R.tokens, {
        "T"
    }, "a page's tokens as the client holds them")
    test.assert_eq(data.game.page, "R")
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages R"
    })
    test.assert_deep_eq(side.notifications.messages, {})
end)

client_case("a refusal is notified and nothing applied", function(side, screen)
    rp_of(side):receive_response({
        success = false,
        error = "Not allowed to change the page \"P\"",
        kind = "pages",
        id = "P",
        entry = mocks.entries_game_data().pages.P
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Not allowed to change the page \"P\""
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

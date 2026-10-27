local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")

local SAVE = "s/games/g/save.lua"

---@class TestDeleteEntryServer
---@field side TestServerSide
---@field files table<string, string> The fake file system, `SAVE` among them

---@param name string
---@param fn fun(server: TestDeleteEntryServer)
local function server_case(name, fn)
    test.case(name, function()
        ---@type table<string, string>
        local files = {
            ["s/games/g/assets/world/w.png"] = "W"
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

---@param server TestDeleteEntryServer
---@return GameData What `save.lua` holds
local function saved(server)
    return table.from_string(assert(server.files[SAVE])) --[[@as GameData]]
end

---@param connection Connection
---@param request DeleteEntryRequest
---@return DeleteEntryResponse
local function delete(connection, request)
    return mocks.request(connection, "DeleteEntryRp", request) --[[@as DeleteEntryResponse]]
end

test.suite("DeleteEntryRp")

server_case("a master deletes a page: the entry and the grants on it go from the data and the save, the push to its readers, the grants to whose changed", function(server)
    local piotr_connection = mocks.join_another("piotr")
    local ewa_connection, ewa = mocks.join_another("ewa")
    mocks.join_game(server.side.connection, "adam")
    mocks.sent(piotr_connection)
    mocks.sent(ewa_connection)
    local response = delete(server.side.connection, {
        kind = "pages",
        id = "Q"
    })
    test.assert_deep_eq(response, {
        success = true,
        kind = "pages",
        id = "Q"
    })
    local game = assert(assert(server.side.server.games):get(mocks.GAME_ID))
    for _, data in ipairs({
        game:get_data(),
        saved(server)
    }) do
        test.assert_eq(data.pages.Q, nil)
        test.assert_deep_eq(data.players.ewa.permissions, {}, "the grant on the page went with it")
    end
    test.assert_deep_eq(ewa:get_permissions():get_grants(), {
        "read"
    })
    test.assert_deep_eq(mocks.sent(piotr_connection), {}, "piotr never read Q")
    local pushes = mocks.sent(ewa_connection)
    test.assert_eq(#pushes, 2)
    test.assert_eq(pushes[1].id, "EntryDeletedRp")
    test.assert_deep_eq(pushes[1].body, {
        kind = "pages",
        id = "Q"
    })
    test.assert_eq(pushes[2].id, "GrantsChangedRp")
    test.assert_deep_eq(pushes[2].body, {
        permissions = {
            "read"
        }
    })
    lifetime.destroy(piotr_connection)
    lifetime.destroy(ewa_connection)
end)

server_case("a session not in a game, an unknown kind or id, a session without write and an entry the game still uses are refused, nothing applied", function(server)
    local response = delete(server.side.connection, {
        kind = "pages",
        id = "Q"
    })
    test.assert_false(response.success)
    test.assert_eq(response.error, "Not in a game")
    mocks.join_game(server.side.connection, "piotr")
    test.assert_eq(delete(server.side.connection, {
        kind = "pages",
        id = "Q"
    }).error, "Not allowed to delete the page \"Q\"")
    mocks.request(server.side.connection, "LogoutRp", {})
    mocks.join_game(server.side.connection, "adam")
    local before = server.files[SAVE]
    ---@type {request: DeleteEntryRequest, error: string}[]
    local refused = {
        {
            request = {
                kind = "pages",
                id = "Z"
            },
            error = "No page with the id \"Z\""
        },
        {
            request = {
                kind = "players",
                id = "piotr"
            },
            error = "Players cannot be deleted"
        },
        {
            request = {
                kind = "pages",
                id = "P"
            },
            error = "The page \"P\" is shown to the players"
        },
        {
            request = {
                kind = "groups",
                id = "player"
            },
            error = "A player is in the group \"player\""
        },
        {
            request = {
                kind = "token_properties",
                id = "hp"
            },
            error = "A token holds the property \"hp\""
        }
    }
    response = mocks.request(server.side.connection, "DeleteEntryRp", {
        kind = "tokens",
        id = "T"
    }) --[[@as DeleteEntryResponse]]
    test.assert_eq(response.error, "No kind \"tokens\"")
    for _, case in ipairs(refused) do
        response = delete(server.side.connection, case.request)
        test.assert_false(response.success, case.error)
        test.assert_eq(response.error, case.error)
        test.assert_eq(response.kind, case.request.kind)
        test.assert_eq(response.id, case.request.id)
    end
    test.assert_eq(server.files[SAVE], before)
end)

server_case("a request from the server's peer for the push is logged and acknowledged with nothing", function(server)
    mocks.join_game(server.side.connection, "adam")
    local before = server.files[SAVE]
    local response = mocks.request(server.side.connection, "EntryDeletedRp", {
        kind = "pages",
        id = "Q"
    })
    test.assert_deep_eq(response, {})
    test.assert_deep_eq(server.side.server.logs[#server.side.server.logs], {
        "EntryDeletedRp is the server's to send: a request from the client ignored"
    })
    test.assert_eq(server.files[SAVE], before)
end)

test.suite("DeleteEntryRp, the client")

---@param name string
---@param fn fun(side: TestClientSide, screen: TestGameScreen)
local function client_case(name, fn)
    test.case(name, function()
        local side = mocks.make_client_session({})
        mocks.join_client_game(side, "ewa", mocks.entries_game_data(), {
            "read",
            "write:pages",
            "view:pages/Q"
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

client_case("delete_entry sends the id; the answer removes the entry and the grants on it, and tells the game screen", function(side, screen)
    side.session:delete_entry("pages", "Q")
    local sent = mocks.sent(side.connection)
    test.assert_eq(#sent, 1)
    test.assert_eq(sent[1].id, "DeleteEntryRp")
    test.assert_deep_eq(sent[1].body, {
        kind = "pages",
        id = "Q"
    })
    test.assert_true(assert(side.client.data).pages.Q ~= nil, "nothing before the answer")
    mocks.answer(side.connection, "DeleteEntryRp", {
        success = true,
        kind = "pages",
        id = "Q"
    })
    local data = assert(side.client.data)
    test.assert_eq(data.pages.Q, nil)
    test.assert_deep_eq(data.players.ewa.permissions, {})
    test.assert_deep_eq(side.session:get_permissions():get_grants(), {
        "read",
        "write:pages"
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages Q"
    })
end)

client_case("a refusal is notified and the entry stays", function(side, screen)
    side.session:delete_entry("pages", "P")
    mocks.answer(side.connection, "DeleteEntryRp", {
        success = false,
        error = "The page \"P\" is shown to the players",
        kind = "pages",
        id = "P"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "The page \"P\" is shown to the players"
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

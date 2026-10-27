local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

---@param name string
---@param fn fun(side: TestClientSide, screen: TestGameScreen)
local function client_case(name, fn)
    test.case(name, function()
        local side = mocks.make_client_session({})
        mocks.join_client_game(side, "ewa", mocks.entries_game_data(), {
            "read",
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

---@param side TestClientSide
---@param body RequestBody
local function push(side, body)
    test.assert_deep_eq(mocks.request(side.connection, "EntryDeletedRp", body), {}, "acknowledged with nothing")
end

test.suite("EntryDeletedRp")

client_case("a deletion removes the entry and the grants on it from the data and the set, and tells the game screen", function(side, screen)
    push(side, {
        kind = "pages",
        id = "Q"
    })
    local data = assert(side.client.data)
    test.assert_eq(data.pages.Q, nil)
    test.assert_deep_eq(data.players.ewa.permissions, {})
    test.assert_deep_eq(side.session:get_permissions():get_grants(), {
        "read"
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages Q"
    })
end)

client_case("an entry the client does not hold, or of a kind never deleted, is logged and ignored", function(side, screen)
    push(side, {
        kind = "pages",
        id = "Z"
    })
    test.assert_deep_eq(side.client.logs[#side.client.logs], {
        "A deletion of the page \"Z\", which this client does not hold, ignored"
    })
    push(side, {
        kind = "players",
        id = "piotr"
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

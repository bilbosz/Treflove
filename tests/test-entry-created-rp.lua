local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

---@param name string
---@param fn fun(side: TestClientSide, screen: TestGameScreen)
local function client_case(name, fn)
    test.case(name, function()
        local side = mocks.make_client_session({})
        mocks.join_client_game(side, "ewa", mocks.entries_game_data(), {
            "read"
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
    test.assert_deep_eq(mocks.request(side.connection, "EntryCreatedRp", body), {}, "acknowledged with nothing")
end

test.suite("EntryCreatedRp")

client_case("a new entry goes to the data and the game screen is told", function(side, screen)
    push(side, {
        kind = "pages",
        id = "C",
        entry = {
            name = "Cellar",
            width = 10,
            pixel_per_meter = 4,
            image = "world/n.png",
            tokens = {}
        }
    })
    push(side, {
        kind = "token_properties",
        id = "speed",
        entry = {
            title = "Speed",
            type = "number"
        }
    })
    local data = assert(side.client.data)
    test.assert_deep_eq(data.pages.C, {
        name = "Cellar",
        width = 10,
        pixel_per_meter = 4,
        image = "world/n.png",
        tokens = {}
    })
    test.assert_deep_eq(data.token_properties.speed, {
        title = "Speed",
        type = "number"
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages C",
        "on_entries_change token_properties speed"
    })
end)

client_case("an entry the client holds already, or of a kind never created, is logged and ignored", function(side, screen)
    push(side, {
        kind = "groups",
        id = "master",
        entry = {
            title = "Again",
            permissions = {}
        }
    })
    test.assert_deep_eq(side.client.logs[#side.client.logs], {
        "A creation of the group \"master\", which this client holds already or cannot hold, ignored"
    })
    push(side, {
        kind = "players",
        id = "frodo",
        entry = {
            group = "player"
        }
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

client_case("an entry pushed after the game was left goes to the data only", function(side, screen)
    local calls = screen.calls
    side.session:leave_game()
    push(side, {
        kind = "groups",
        id = "guests",
        entry = {
            title = "Guests",
            permissions = {
                "read"
            }
        }
    })
    test.assert_deep_eq(assert(side.client.data).groups.guests, {
        title = "Guests",
        permissions = {
            "read"
        }
    })
    test.assert_deep_eq(calls, {})
end)

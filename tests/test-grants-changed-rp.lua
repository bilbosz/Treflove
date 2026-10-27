local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local permissions = require("game.permissions")

---@param name string
---@param fn fun(side: TestClientSide, screen: TestGameScreen)
local function client_case(name, fn)
    test.case(name, function()
        local side = mocks.make_client_session({})
        mocks.join_client_game(side, "piotr", mocks.entries_game_data(), {
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
---@param grants string[]
local function push(side, grants)
    test.assert_deep_eq(mocks.request(side.connection, "GrantsChangedRp", {
        permissions = grants
    }), {}, "acknowledged with nothing")
end

test.suite("GrantsChangedRp")

client_case("the session's grants are replaced and the game screen told", function(side, screen)
    push(side, {
        "read",
        "write:tokens"
    })
    test.assert_deep_eq(side.session:get_permissions():get_grants(), {
        "read",
        "write:tokens"
    })
    test.assert_true(side.session:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS))
    test.assert_deep_eq(screen.calls, {
        "on_grants_change"
    })
end)

client_case("grants pushed after the game was left go to the set only", function(side, screen)
    local calls = screen.calls
    side.session:leave_game()
    test.assert_false(lifetime.alive(screen))
    push(side, {
        "write"
    })
    test.assert_true(side.session:is_allowed(permissions.Action.WRITE))
    test.assert_deep_eq(calls, {})
end)

test.case("grants pushed to a session without a game are logged and ignored", function()
    local side = mocks.make_client_session({})
    ---@type boolean, any
    local ok, err = pcall(function()
        push(side, {
            "write"
        })
        test.assert_deep_eq(side.client.logs[#side.client.logs], {
            "Grants for a session without a game, ignored"
        })
        test.assert_false(side.session:is_allowed(permissions.Action.WRITE))
    end)
    mocks.finish_client_session(side)
    if not ok then
        error(err, 0)
    end
end)

test.suite("GrantsChangedRp, the server")

test.case("a push a client sends to the server is logged, acknowledged with nothing and changes no grants", function()
    local side = mocks.make_server_session(mocks.entries_game_data, {})
    ---@type boolean, any
    local ok, err = pcall(function()
        mocks.join_game(side.connection, "piotr")
        local response = mocks.request(side.connection, "GrantsChangedRp", {
            permissions = {
                "write"
            }
        })
        test.assert_deep_eq(response, {})
        test.assert_deep_eq(side.server.logs[#side.server.logs], {
            "GrantsChangedRp is the server's to send: a request from the client ignored"
        })
        test.assert_false(side.session:is_allowed(permissions.Action.WRITE))
    end)
    mocks.finish_server_session(side)
    if not ok then
        error(err, 0)
    end
end)

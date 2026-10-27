local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

---@return GameData
local function game_data()
    return {
        name = "Meadow",
        game = {
            page = "P"
        },
        groups = {},
        players = {
            adam = {
                group = "master"
            }
        },
        pages = {},
        token_properties = {},
        tokens = {}
    }
end

---@return string
local function template()
    local data = game_data()
    data.name = ""
    data.players = {}
    return table.to_string(data)
end

---@param side TestServerSide
---@param name string
---@return CreateGameResponse
local function create(side, name)
    return mocks.request(side.connection, "CreateGameRp", {
        name = name
    }) --[[@as CreateGameResponse]]
end

test.suite("CreateGameRp")

test.case("a logged-in session creates a game it is the master of; before the login, or with a taken name, it is refused", function()
    local side = mocks.make_server_session(game_data, {
        ["server/template/save.lua"] = template()
    })
    test.assert_deep_eq(create(side, "The Shire"), {
        success = false,
        error = "Not logged in"
    })
    test.assert_eq(mocks.log_in(side.connection, "adam"), "adam")
    test.assert_deep_eq(create(side, "The Shire"), {
        success = true,
        id = "the-shire"
    })
    local game = assert(assert(side.server.games):get("the-shire"))
    test.assert_eq(game:get_name(), "The Shire")
    test.assert_deep_eq(game:get_data().players, {
        adam = {
            group = "master"
        }
    })
    test.assert_deep_eq(create(side, "the shire"), {
        success = false,
        error = "A game named \"The Shire\" exists already"
    })
    test.assert_false(side.session:is_in_game(), "creating a game does not select it: the client joins it")
    mocks.finish_server_session(side)
end)

test.case("the client notifies a refusal", function()
    local side = mocks.make_client_session({})
    ---@diagnostic disable-next-line: invisible
    local rp = side.session._create_game_rp
    rp:receive_response({
        success = true,
        id = "the-shire"
    })
    rp:receive_response({
        success = false,
        error = "A game needs a name with a letter or a digit"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "A game needs a name with a letter or a digit"
    })
    mocks.finish_client_session(side)
end)

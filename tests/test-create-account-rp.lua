local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

---@return GameData
local function game_data()
    return {
        name = "G",
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

---@param side TestServerSide
---@param login string
---@param name string
---@return CreateAccountResponse
local function create(side, login, name)
    return mocks.request(side.connection, "CreateAccountRp", {
        login = login,
        name = name,
        auth = mocks.client_auth(login)
    }) --[[@as CreateAccountResponse]]
end

test.suite("CreateAccountRp")

test.case("the server makes the account, which then logs in; a taken or bad login is refused with the reason", function()
    local side = mocks.make_server_session(game_data, {})
    test.assert_deep_eq(create(side, "frodo", "Frodo"), {
        success = true
    })
    test.assert_eq(assert(side.server.accounts):get("frodo").name, "Frodo")
    test.assert_deep_eq(create(side, "frodo", "Frodo"), {
        success = false,
        error = "The login \"frodo\" is taken already"
    })
    test.assert_deep_eq(create(side, "", "Nobody"), {
        success = false,
        error = "A login cannot be empty"
    })
    test.assert_deep_eq(create(side, "sam", ""), {
        success = false,
        error = "A name cannot be empty"
    })
    test.assert_false(side.session:is_logged_in(), "making an account logs nobody in")
    test.assert_eq(mocks.log_in(side.connection, "frodo"), "frodo")
    mocks.finish_server_session(side)
end)

test.case("the client notifies the outcome", function()
    local side = mocks.make_client_session({})
    ---@diagnostic disable-next-line: invisible
    local rp = side.session._login._create_account_rp
    rp:receive_response({
        success = true
    })
    rp:receive_response({
        success = false,
        error = "The login \"frodo\" is taken already"
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Account created",
        "The login \"frodo\" is taken already"
    })
    mocks.finish_client_session(side)
end)

test.case("the client's sign-up sends the login, the name and the auth a login with the same password sends", function()
    local side = mocks.make_client_session({})
    side.session:sign_up("frodo", "Frodo", "ring")
    local out = side.connection:get_out_channel()
    test.assert_eq(out:getCount(), 1)
    side.session:login("frodo", "ring")
    test.assert_eq(out:getCount(), 2)
    ---@type Request[]
    local requests = {}
    while out:getCount() > 0 do
        table.insert(requests, mocks.decode_request(out:pop() --[[@as string]] ))
    end
    test.assert_eq(requests[1].id, "CreateAccountRp")
    local body = requests[1].body --[[@as CreateAccountRequest]]
    test.assert_eq(body.login, "frodo")
    test.assert_eq(body.name, "Frodo")
    test.assert_eq(body.auth, (requests[2].body --[[@as LoginRequest]] ).auth, "the auth of the login with the same password")
    mocks.finish_client_session(side)
end)

local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")

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

---Delivers the server's push to the client and runs a frame
---@param client GameClient
---@param body TokenCreatedRequest
local function push(client, body)
    ---@type Request
    local request = {
        source = "s",
        id = "TokenCreatedRp",
        body = body
    }
    client.connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(request)))
    app = client.app
    client.app.update_event:trigger(0.016)
end

---@param avatar string|nil Defaults to one the client's store has
---@return TokenData
local function new_token(avatar)
    return {
        name = "Gandalf",
        diameter = 1,
        avatar = avatar or "token/s.png",
        position = {
            6,
            7
        }
    }
end

test.suite("TokenCreatedRp")

client_case("a token on the shown page is added to the data, the page's list and the page at its position, and acknowledged with nothing", {
    "read"
}, function(client)
    push(client, {
        id = "Gandalf",
        page = "P",
        token = new_token()
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenCreatedRp"), {})
    local data = assert(client.app.data)
    test.assert_deep_eq(data.tokens.Gandalf, new_token())
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza",
        "Smaug",
        "Gandalf"
    })
    local token = game_client.find_token(client, "Gandalf")
    test.assert_eq(token:get_data(), data.tokens.Gandalf)
    test.assert_deep_eq({
        token:get_position()
    }, {
        6,
        7
    })
    test.assert_eq(#client.game_screen:get_page():get_tokens(), 3)
end)

client_case("a token on another page goes to the data and that page's list only", {
    "read"
}, function(client)
    push(client, {
        id = "Gandalf",
        page = "Q",
        token = new_token()
    })
    local data = assert(client.app.data)
    test.assert_deep_eq(data.tokens.Gandalf, new_token())
    test.assert_deep_eq(data.pages.Q.tokens, {
        "Gandalf"
    })
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza",
        "Smaug"
    })
    test.assert_eq(client.game_screen:get_page():try_find_token("Gandalf"), nil)
end)

client_case("a token on a page the client does not hold goes to the data only, with a log", {
    "read"
}, function(client)
    push(client, {
        id = "Gandalf",
        page = "Nowhere",
        token = new_token()
    })
    local data = assert(client.app.data)
    test.assert_deep_eq(data.tokens.Gandalf, new_token())
    test.assert_eq(data.pages.Nowhere, nil)
    test.assert_deep_eq(client.app.logs[#client.app.logs], {
        "The new token \"Gandalf\" is on the page \"Nowhere\", which this client does not hold: in the data only"
    })
    test.assert_eq(client.game_screen:get_page():try_find_token("Gandalf"), nil)
end)

client_case("a token the client holds already is ignored with a log", {
    "read"
}, function(client)
    push(client, {
        id = "Smaug",
        page = "P",
        token = new_token()
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenCreatedRp"), {})
    test.assert_deep_eq(client.app.logs[#client.app.logs], {
        "A new token \"Smaug\", which this client holds already, ignored"
    })
    test.assert_deep_eq(assert(client.app.data).tokens, game_client.game_data().tokens)
    test.assert_eq(#client.game_screen:get_page():get_tokens(), 2)
end)

client_case("an avatar the store lacks is downloaded first and the token added once it is in", {
    "read"
}, function(client)
    push(client, {
        id = "Gandalf",
        page = "P",
        token = new_token("token/n.png")
    })
    local download = game_client.pop_request(client, "DownloadMissingAssetsRp") --[[@as DownloadMissingAssetsRequest]]
    test.assert_deep_eq(download.list, {
        "token/n.png"
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenCreatedRp"), {})
    local data = assert(client.app.data)
    test.assert_eq(data.tokens.Gandalf, nil, "not before the avatar is in")
    test.assert_eq(client.game_screen:get_page():try_find_token("Gandalf"), nil)
    game_client.answer(client, "DownloadMissingAssetsRp", {
        success = true,
        contents = {
            ["token/n.png"] = love.data.encode("string", "base64", "N")
        }
    })
    test.assert_eq(love.filesystem.read("c/games/g/assets/token/n.png"), "N")
    test.assert_deep_eq(data.tokens.Gandalf, new_token("token/n.png"))
    test.assert_eq(game_client.find_token(client, "Gandalf"):get_data().avatar, "token/n.png")
end)

client_case("a token pushed after the game was left goes to the data and the page's list", {
    "read"
}, function(client)
    client.session:leave_game()
    push(client, {
        id = "Gandalf",
        page = "P",
        token = new_token()
    })
    local data = assert(client.app.data)
    test.assert_deep_eq(data.tokens.Gandalf, new_token())
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza",
        "Smaug",
        "Gandalf"
    })
end)

client_case("an avatar downloaded after the game was left adds the token to the data alone", {
    "read"
}, function(client)
    push(client, {
        id = "Gandalf",
        page = "P",
        token = new_token("token/n.png")
    })
    game_client.pop_request(client, "DownloadMissingAssetsRp")
    client.session:leave_game()
    game_client.answer(client, "DownloadMissingAssetsRp", {
        success = true,
        contents = {
            ["token/n.png"] = love.data.encode("string", "base64", "N")
        }
    })
    local data = assert(client.app.data)
    test.assert_deep_eq(data.tokens.Gandalf, new_token("token/n.png"))
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza",
        "Smaug",
        "Gandalf"
    })
end)

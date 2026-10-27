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
---@param body TokenChangedRequest
local function push(client, body)
    ---@type Request
    local request = {
        source = "s",
        id = "TokenChangedRp",
        body = body
    }
    client.connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(request)))
    app = client.app
    client.app.update_event:trigger(0.016)
end

---@param id string A token of `game_client.game_data()`
---@param changes table<string, TokenDataValue>
---@return TokenData The token's entry with the changes
local function changed(id, changes)
    local token = game_client.game_data().tokens[id]
    ---@type table<string, TokenDataValue>
    local values = token
    for key, value in pairs(changes) do
        values[key] = value
    end
    return token
end

test.suite("TokenChangedRp")

client_case("a position is applied to the data and to the page's token, and acknowledged with nothing", {
    "read"
}, function(client)
    push(client, {
        id = "Smaug",
        token = changed("Smaug", {
            position = {
                7,
                8
            }
        })
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenChangedRp"), {})
    test.assert_deep_eq({
        game_client.find_token(client, "Smaug"):get_position()
    }, {
        7,
        8
    })
    test.assert_deep_eq(assert(client.app.data).tokens.Smaug.position, {
        7,
        8
    })
end)

client_case("a rename is applied to the data, the token, the page's list and the set", {
    "read",
    "write:tokens/Bilbosza"
}, function(client)
    local token = game_client.find_token(client, "Bilbosza")
    push(client, {
        id = "Bilbosza",
        new_id = "Bilbo",
        token = changed("Bilbosza", {
            name = "Bilbo Baggins"
        })
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenChangedRp"), {})
    local data = assert(client.app.data)
    test.assert_eq(token:get_id(), "Bilbo")
    test.assert_eq(token:get_data().name, "Bilbo Baggins")
    test.assert_eq(data.tokens.Bilbosza, nil)
    test.assert_eq(data.tokens.Bilbo, token:get_data())
    test.assert_deep_eq(client.game_screen:get_page():get_data().tokens, {
        "Bilbo",
        "Smaug"
    })
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read",
        "write:tokens/Bilbo"
    })
    test.assert_true(token:is_writable())
end)

client_case("a token the shown page does not hold is changed and renamed in the data only", {
    "read",
    "view:tokens/Gollum"
}, function(client)
    push(client, {
        id = "Gollum",
        new_id = "Smeagol",
        token = changed("Gollum", {
            position = {
                3,
                3
            },
            name = "Smeagol"
        })
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenChangedRp"), {})
    local data = assert(client.app.data)
    test.assert_eq(data.tokens.Gollum, nil)
    test.assert_deep_eq(data.tokens.Smeagol, changed("Gollum", {
        position = {
            3,
            3
        },
        name = "Smeagol"
    }))
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read",
        "view:tokens/Smeagol"
    })
end)

client_case("a token the client does not hold is ignored with a log", {
    "read"
}, function(client)
    push(client, {
        id = "Nobody",
        token = changed("Smaug", {})
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenChangedRp"), {})
    test.assert_deep_eq(client.app.logs[#client.app.logs], {
        "A change of the token \"Nobody\", which this client does not hold, ignored"
    })
    test.assert_deep_eq(assert(client.app.data).tokens, game_client.game_data().tokens)
end)

client_case("an avatar the store lacks is downloaded first and applied once it is in", {
    "read"
}, function(client)
    local token = game_client.find_token(client, "Smaug")
    push(client, {
        id = "Smaug",
        token = changed("Smaug", {
            avatar = "token/n.png",
            name = "Smaug the Golden"
        })
    })
    local download = game_client.pop_request(client, "DownloadMissingAssetsRp") --[[@as DownloadMissingAssetsRequest]]
    test.assert_deep_eq(download.list, {
        "token/n.png"
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenChangedRp"), {})
    test.assert_eq(token:get_data().name, "Smaug the Golden", "the rest at once")
    test.assert_eq(token:get_data().avatar, "token/s.png", "the avatar once it is in")
    game_client.answer(client, "DownloadMissingAssetsRp", {
        success = true,
        contents = {
            ["token/n.png"] = love.data.encode("string", "base64", "N")
        }
    })
    test.assert_eq(token:get_data().avatar, "token/n.png")
    test.assert_eq(love.filesystem.read("c/games/g/assets/token/n.png"), "N")
end)

client_case("an avatar the store has is applied at once", {
    "read"
}, function(client)
    local token = game_client.find_token(client, "Smaug")
    push(client, {
        id = "Smaug",
        token = changed("Smaug", {
            avatar = "token/b.png"
        })
    })
    test.assert_eq(client.connection:get_out_channel():getCount(), 1, "the acknowledgement only")
    test.assert_eq(token:get_data().avatar, "token/b.png")
end)

client_case("a selected token's change rebuilds the token panel with the new values", {
    "read"
}, function(client)
    game_client.select(client, {
        "Smaug"
    })
    push(client, {
        id = "Smaug",
        token = changed("Smaug", {
            name = "Smaug the Golden"
        })
    })
    ---@type string|nil
    local shown
    ---@diagnostic disable-next-line: invisible
    for _, property in ipairs(client.game_screen:get_token_panel()._properties) do
        if property.key == "name" then
            shown = assert(property.input):get_text()
        end
    end
    test.assert_eq(shown, "Smaug the Golden")
end)

client_case("a change pushed after the game was left goes to the data", {
    "read"
}, function(client)
    client.session:leave_game()
    push(client, {
        id = "Smaug",
        token = changed("Smaug", {
            position = {
                9,
                9
            }
        })
    })
    test.assert_deep_eq(game_client.pop_request(client, "TokenChangedRp"), {})
    test.assert_deep_eq(assert(client.app.data).tokens.Smaug.position, {
        9,
        9
    })
end)

local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local lifetime = require("lifetime")
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
---@param id string
local function push(client, id)
    ---@type Request
    local request = {
        source = "s",
        id = "TokenDeletedRp",
        body = {
            id = id
        }
    }
    client.connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(request)))
    app = client.app
    client.app.update_event:trigger(0.016)
end

test.suite("TokenDeletedRp")

client_case("a token on the shown page leaves the page, destroyed, the data, every page's list and the client's grants, and is acknowledged with nothing", {
    "read",
    "write:tokens/Smaug",
    "view:tokens/Smaug",
    "view:tokens/Bilbosza"
}, function(client)
    local data = assert(client.app.data)
    data.pages.Q.tokens = {
        "Smaug"
    }
    local page = client.game_screen:get_page()
    local smaug = game_client.find_token(client, "Smaug")
    local bilbosza = game_client.find_token(client, "Bilbosza")
    push(client, "Smaug")
    test.assert_deep_eq(game_client.pop_request(client, "TokenDeletedRp"), {})
    test.assert_false(lifetime.alive(smaug))
    test.assert_deep_eq(page:get_tokens(), {
        bilbosza
    })
    test.assert_eq(data.tokens.Smaug, nil)
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza"
    })
    test.assert_deep_eq(data.pages.Q.tokens, {})
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read",
        "view:tokens/Bilbosza"
    })
end)

client_case("a selected token leaves the selection and the token panel is rebuilt for what is left", {
    "read"
}, function(client)
    game_client.select(client, {
        "Bilbosza",
        "Smaug"
    })
    local selection = client.game_screen:get_selection()
    local bilbosza = game_client.find_token(client, "Bilbosza")
    push(client, "Smaug")
    test.assert_deep_eq(selection:get_select_set(), {
        [bilbosza] = true
    })
    ---@type string|nil
    local shown
    ---@diagnostic disable-next-line: invisible
    for _, property in ipairs(client.game_screen:get_token_panel()._properties) do
        if property.key == "name" then
            shown = assert(property.input):get_text()
        end
    end
    test.assert_eq(shown, "Bilbosza Wielka", "the panel shows Bilbosza alone, not the multivalue of two")
end)

client_case("a token deleted during a drag leaves the drag, whose end sends the moves of the others", {
    "read",
    "write"
}, function(client)
    game_client.select(client, {
        "Bilbosza",
        "Smaug"
    })
    local page = client.game_screen:get_page()
    local px, py = page:get_position()
    page:on_pointer_down(px + 100, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
    page:on_pointer_move(px + 140, py + 100)
    push(client, "Smaug")
    game_client.pop_request(client, "TokenDeletedRp")
    page:on_pointer_move(px + 160, py + 100)
    page:on_pointer_up(px + 160, py + 100, Consts.PAGE_DRAG_TOKEN_BUTTON)
    local request = game_client.pop_request(client, "UpdateTokenRp") --[[@as UpdateTokenRequest]]
    test.assert_eq(request.id, "Bilbosza")
    test.assert_eq(client.connection:get_out_channel():getCount(), 0, "nothing for Smaug")
end)

client_case("a token on no page leaves the data alone", {
    "read",
    "view:tokens/Gollum"
}, function(client)
    push(client, "Gollum")
    local data = assert(client.app.data)
    test.assert_eq(data.tokens.Gollum, nil)
    test.assert_eq(#client.game_screen:get_page():get_tokens(), 2)
    test.assert_deep_eq(client.session:get_permissions():get_grants(), {
        "read"
    })
end)

client_case("a token pushed after the game was left leaves the data", {
    "read"
}, function(client)
    client.session:leave_game()
    push(client, "Smaug")
    local data = assert(client.app.data)
    test.assert_eq(data.tokens.Smaug, nil)
    test.assert_deep_eq(data.pages.P.tokens, {
        "Bilbosza"
    })
end)

client_case("a token the client does not hold is ignored with a log", {
    "read"
}, function(client)
    push(client, "Nobody")
    test.assert_deep_eq(game_client.pop_request(client, "TokenDeletedRp"), {})
    test.assert_deep_eq(client.app.logs[#client.app.logs], {
        "A deletion of the token \"Nobody\", which this client does not hold, ignored"
    })
    test.assert_deep_eq(assert(client.app.data).tokens, game_client.game_data().tokens)
end)

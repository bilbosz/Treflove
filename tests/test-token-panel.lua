local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")

---@param client GameClient
---@return TokenPanelProperty[]
local function properties(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._properties
end

---@param client GameClient
---@return TextButton|nil
local function apply_button(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._apply_button
end

---@param client GameClient
---@return TextButton|nil
local function cancel_button(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._cancel_button
end

---@param client GameClient
---@param read_only boolean
---@param message string
local function assert_inputs_read_only(client, read_only, message)
    local fields = properties(client)
    test.assert_true(#fields > 0, "the selection has properties")
    for _, property in ipairs(fields) do
        test.assert_eq(assert(property.input):is_read_only(), read_only, message .. ": " .. property.key)
    end
end

---@param grants string[]
---@param fn fun(client: GameClient)
local function with_client(grants, fn)
    local client = game_client.enter(grants)
    ---@type boolean, any
    local ok, err = pcall(fn, client)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

test.suite("TokenPanel")

test.case("a selection of writable tokens has editable inputs and an Apply button", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        assert_inputs_read_only(client, false, "editable")
        test.assert_true(apply_button(client) ~= nil, "an Apply button")
        test.assert_true(cancel_button(client) ~= nil, "a Cancel button")
    end)
end)

test.case("a token is asked by its key, not its display name", function()
    with_client({
        "read",
        "write:tokens/Bilbosza"
    }, function(client)
        local token = game_client.find_token(client, "Bilbosza")
        test.assert_eq(token:get_data().name, "Bilbosza Wielka")
        test.assert_true(token:is_writable())
        test.assert_false(game_client.find_token(client, "Smaug"):is_writable())
        game_client.select(client, {
            "Bilbosza"
        })
        assert_inputs_read_only(client, false, "editable")
        test.assert_true(apply_button(client) ~= nil)
    end)
end)

test.case("a selection with one token the player may not write is read-only, with Cancel and no Apply", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        assert_inputs_read_only(client, true, "read-only")
        test.assert_eq(apply_button(client), nil, "no Apply button")
        test.assert_true(cancel_button(client) ~= nil, "a Cancel button")
    end)
end)

test.case("the read-only state follows the selection", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Smaug"
        })
        assert_inputs_read_only(client, true, "read-only")
        test.assert_eq(apply_button(client), nil)
        game_client.select(client, {
            "Bilbosza"
        })
        assert_inputs_read_only(client, false, "editable again")
        test.assert_true(apply_button(client) ~= nil)
    end)
end)

test.case("the game master writes every token", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        assert_inputs_read_only(client, false, "editable")
        test.assert_true(apply_button(client) ~= nil)
    end)
end)

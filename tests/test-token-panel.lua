local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")

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
        if property.def.type ~= "image" then
            test.assert_eq(assert(property.input):is_read_only(), read_only, message .. ": " .. property.key)
        end
    end
end

---@param client GameClient
---@param key string
---@return TokenPanelProperty
local function property_by_key(client, key)
    for _, property in ipairs(properties(client)) do
        if property.key == key then
            return property
        end
    end
    error("no property " .. key)
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

test.case("the properties sit in a scroll view that ends a padding above the buttons", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local panel = client.game_screen:get_token_panel()
        ---@diagnostic disable-next-line: invisible
        local view = panel._scroll_view
        local content = view:get_content()
        for _, property in ipairs(properties(client)) do
            test.assert_eq(assert(property.title):get_parent(), content)
            test.assert_eq(assert(property.input):get_parent(), content)
        end
        local panel_w = panel:get_size()
        local view_w, view_h = view:get_size()
        local _, cancel_y = assert(cancel_button(client)):get_position()
        test.assert_eq(view_w, panel_w)
        test.assert_eq(view_h, cancel_y - Consts.PADDING)
        local content_w, content_h = view:get_content_size()
        test.assert_eq(content_w, panel_w)
        local last = properties(client)[#properties(client)]
        local _, input_y, _, input_h = assert(last.input):get_position_and_size()
        test.assert_eq(content_h, input_y + input_h + Consts.PADDING)

        panel:on_resize(panel_w, 100)
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(view, panel._scroll_view, "the same view after a rebuild")
        _, cancel_y = assert(cancel_button(client)):get_position()
        test.assert_eq(select(2, view:get_size()), cancel_y - Consts.PADDING)
        local _, max_y = view:get_max_scroll()
        test.assert_true(max_y > 0, "the properties overflow a short panel")
    end)
end)

test.case("an image property shows its path read-only, with an Assets button; differing values are multivalue", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local avatar = property_by_key(client, "avatar")
        test.assert_eq(assert(avatar.input):get_text(), "token/b.png")
        test.assert_true(avatar.input:is_read_only(), "chosen in the workspace, not typed")
        test.assert_eq(assert(avatar.button):get_text(), "Browse...")
        local _, input_y, _, input_h = avatar.input:get_position_and_size()
        local _, button_y = assert(avatar.button):get_position()
        test.assert_true(button_y >= input_y + input_h, "the button under the path")

        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        avatar = property_by_key(client, "avatar")
        test.assert_true(assert(avatar.input):is_multivalue_default())
    end)
end)

test.case("a read-only selection's image property only shows its asset", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Smaug"
        })
        test.assert_eq(assert(property_by_key(client, "avatar").button):get_text(), "Show in assets...")
    end)
end)

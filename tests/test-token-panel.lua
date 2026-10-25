local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")
local permissions = require("game.permissions")

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
---@return Text|nil
local function id_title(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._id_title
end

---@param client GameClient
---@return TextInput|nil
local function id_input(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._id_input
end

---@param client GameClient
---@param id string
---@return string[] The notifications the apply raised
local function apply_id(client, id)
    local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
    notifications.messages = {}
    assert(id_input(client)):set_text(id)
    game_client.click(client, assert(apply_button(client)))
    return notifications.messages
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

test.case("a token is asked by its id, not its display name", function()
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

test.case("one writable token shows its id editable, above the properties in the scroll view", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local title, input = assert(id_title(client)), assert(id_input(client))
        test.assert_eq(title:get_text(), "Id")
        test.assert_eq(input:get_text(), "Bilbosza")
        test.assert_false(input:is_read_only())
        test.assert_false(input:is_multivalue())
        ---@diagnostic disable-next-line: invisible
        local view = client.game_screen:get_token_panel()._scroll_view
        local content = view:get_content()
        test.assert_eq(title:get_parent(), content)
        test.assert_eq(input:get_parent(), content)
        local title_x, title_y = title:get_position()
        test.assert_eq(title_x, Consts.PADDING)
        test.assert_eq(title_y, 0)
        local _, title_h = title:get_size()
        local input_x, input_y, input_w, input_h = input:get_position_and_size()
        test.assert_eq(input_x, Consts.PADDING)
        test.assert_eq(input_y, title_h * Consts.PANEL_FIELD_SCALE)
        local first = properties(client)[1]
        local _, _, property_w, property_h = assert(first.input):get_position_and_size()
        test.assert_eq(input_w, property_w)
        test.assert_eq(input_h, property_h)
        local _, first_y = assert(first.title):get_position()
        test.assert_eq(first_y, input_y + input_h + Consts.PADDING, "the properties start under the field")
        local _, content_h = view:get_content_size()
        local last = properties(client)[#properties(client)]
        local _, last_y, _, last_h = assert(last.input):get_position_and_size()
        test.assert_eq(content_h, last_y + last_h + Consts.PADDING, "the content holds the field too")
    end)
end)

test.case("one token the player may not write shows its id read-only", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Smaug"
        })
        local input = assert(id_input(client))
        test.assert_eq(input:get_text(), "Smaug")
        test.assert_true(input:is_read_only())
        test.assert_false(input:is_multivalue())
    end)
end)

test.case("several tokens show the id read-only and multivalue, in the yellowish disabled color", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local input = assert(id_input(client))
        test.assert_true(input:is_read_only(), "even for a writable selection")
        test.assert_true(input:is_multivalue_default())
        test.assert_eq(input:get_text(), "")
        ---@diagnostic disable-next-line: invisible
        test.assert_deep_eq(input._background:get_color(), Consts.BUTTON_MULTIVALUE_READ_ONLY_COLOR)
        test.assert_deep_eq(apply_id(client, "Bilbo"), {}, "nothing to refuse")
        test.assert_eq(game_client.find_token(client, "Bilbosza"):get_id(), "Bilbosza", "no id applied")
        test.assert_eq(game_client.find_token(client, "Smaug"):get_id(), "Smaug")
    end)
end)

test.case("no token selected: no id field", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        test.assert_true(id_input(client) ~= nil)
        game_client.select(client, {})
        test.assert_eq(id_title(client), nil)
        test.assert_eq(id_input(client), nil)
    end)
end)

---@param client GameClient
---@param grant_key string The key of the player's write grant on the token
local function assert_renamed(client, grant_key)
    local data = assert(client.app.data)
    local entry = data.tokens.Bilbosza
    local token = game_client.find_token(client, "Bilbosza")
    test.assert_deep_eq(apply_id(client, "Bilbo"), {})
    test.assert_eq(token:get_id(), "Bilbo")
    test.assert_eq(data.tokens.Bilbosza, nil)
    test.assert_eq(data.tokens.Bilbo, entry, "the same entry under the new id")
    test.assert_deep_eq(client.game_screen:get_page():get_data().tokens, {
        "Bilbo",
        "Smaug"
    })
    test.assert_eq(game_client.find_token(client, "Bilbo"), token)
    test.assert_true(token:is_writable(), "still writable under " .. grant_key)
    local set = client.session:get_permissions()
    test.assert_true(set:allows(permissions.Action.WRITE, permissions.Kind.TOKENS, "Bilbo"))
    test.assert_false(set:allows(permissions.Action.WRITE, permissions.Kind.TOKENS, "Bilbosza"))
end

test.case("applying a new id renames the token, its entry, the page's list and the grant on it", function()
    with_client({
        "read",
        "write:tokens/Bilbosza"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        assert_renamed(client, "write:tokens/Bilbosza")
        test.assert_deep_eq(client.session:get_permissions():get_grants(), {
            "read",
            "write:tokens/Bilbo"
        })
    end)
end)

test.case("a token owned by the player stays writable under its new id", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        assert_renamed(client, "write:tokens/@owned")
        test.assert_deep_eq(client.session:get_permissions():get_grants(), {
            "read",
            "write:tokens/@owned"
        })
    end)
end)

test.case("an id another token has, or an empty one, is refused with a notification and changes nothing", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local data = assert(client.app.data)
        local bilbosza, smaug = data.tokens.Bilbosza, data.tokens.Smaug
        local token = game_client.find_token(client, "Bilbosza")
        test.assert_deep_eq(apply_id(client, "Smaug"), {
            "A token with the id \"Smaug\" already exists"
        })
        test.assert_eq(assert(id_input(client)):get_text(), "Smaug", "the field keeps the typed text")
        test.assert_deep_eq(apply_id(client, ""), {
            "An id must not be empty"
        })
        test.assert_eq(token:get_id(), "Bilbosza")
        test.assert_eq(data.tokens.Bilbosza, bilbosza)
        test.assert_eq(data.tokens.Smaug, smaug)
        test.assert_deep_eq(client.game_screen:get_page():get_data().tokens, {
            "Bilbosza",
            "Smaug"
        })
    end)
end)

test.case("the other properties apply when the id is refused", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        assert(property_by_key(client, "name").input):set_text("Bilbo the Great")
        test.assert_deep_eq(apply_id(client, "@me"), {
            "An id must not start with \"@\""
        })
        local token = game_client.find_token(client, "Bilbosza")
        test.assert_eq(token:get_data().name, "Bilbo the Great")
    end)
end)

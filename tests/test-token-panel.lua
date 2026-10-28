local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")
local permissions = require("game.permissions")
local lifetime = require("lifetime")

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
        test.assert_eq(title_y, Consts.PADDING, "a padding from the top of the panel")
        local _, title_h = title:get_size()
        local input_x, input_y, input_w, input_h = input:get_position_and_size()
        test.assert_eq(input_x, Consts.PADDING)
        test.assert_eq(input_y, Consts.PADDING + title_h * Consts.PANEL_FIELD_SCALE)
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

---@param client GameClient
---@return UpdateTokenRequest[] The requests the client sent since the last call, by token id order
local function sent_updates(client)
    ---@type UpdateTokenRequest[]
    local requests = {}
    while client.connection:get_out_channel():getCount() > 0 do
        table.insert(requests, game_client.pop_request(client, "UpdateTokenRp") --[[@as UpdateTokenRequest]] )
    end
    table.sort(requests, function(a, b)
        return a.id < b.id
    end)
    return requests
end

test.case("an apply sends the rename and the changed properties of the token, and nothing when nothing changed", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        assert(property_by_key(client, "name").input):set_text("Bilbo the Great")
        local diameter = assert(property_by_key(client, "diameter").input) --[[@as NumberInput]]
        diameter:set_number(2)
        test.assert_deep_eq(apply_id(client, "Bilbo"), {})
        test.assert_deep_eq(sent_updates(client), {
            {
                id = "Bilbosza",
                new_id = "Bilbo",
                changes = {
                    name = "Bilbo the Great",
                    diameter = 2
                }
            }
        })
        game_client.click(client, assert(apply_button(client)))
        test.assert_deep_eq(sent_updates(client), {}, "applied again, nothing changed")
        test.assert_deep_eq(apply_id(client, "Baggins"), {})
        test.assert_deep_eq(sent_updates(client), {
            {
                id = "Bilbo",
                new_id = "Baggins",
                changes = {}
            }
        }, "a rename alone")
    end)
end)

test.case("an apply over several tokens sends one update per token the change reached", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local name = assert(property_by_key(client, "name").input)
        name:set_text("Smaug")
        name:on_edit("Smaug")
        game_client.click(client, assert(apply_button(client)))
        test.assert_deep_eq(sent_updates(client), {
            {
                id = "Bilbosza",
                changes = {
                    name = "Smaug"
                }
            }
        }, "Smaug had the name already")
    end)
end)

test.case("an image chosen in the assets workspace sends an update per token whose property changed", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local panel = client.game_screen:get_token_panel()
        ---@diagnostic disable-next-line: invisible
        panel:_set_image("avatar", "token/s.png")
        test.assert_deep_eq(sent_updates(client), {
            {
                id = "Bilbosza",
                changes = {
                    avatar = "token/s.png"
                }
            }
        })
        test.assert_eq(game_client.find_token(client, "Bilbosza"):get_data().avatar, "token/s.png")
    end)
end)

---@param client GameClient
---@return TextButton|nil
local function delete_button(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._delete_button
end

test.case("a writable selection has a Delete button; a read-only or an empty one has none", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        test.assert_eq(assert(delete_button(client)):get_text(), "Delete")
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        test.assert_eq(delete_button(client), nil, "Smaug is not writable")
        game_client.select(client, {})
        test.assert_eq(delete_button(client), nil, "nothing selected, nothing to delete")
    end)
end)

test.case("Delete sends one deletion per selected token; the answers remove them and the panel shows the empty selection", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        game_client.click(client, assert(delete_button(client)))
        ---@type string[]
        local ids = {}
        while client.connection:get_out_channel():getCount() > 0 do
            local request = game_client.pop_request(client, "DeleteTokenRp") --[[@as DeleteTokenRequest]]
            table.insert(ids, request.id)
        end
        test.assert_deep_eq(ids, {
            "Bilbosza",
            "Smaug"
        })
        test.assert_true(id_input(client) ~= nil, "nothing removed before the answers")
        for _, id in ipairs(ids) do
            game_client.answer(client, "DeleteTokenRp", {
                success = true,
                id = id
            })
        end
        test.assert_deep_eq(client.game_screen:get_page():get_tokens(), {})
        test.assert_eq(id_input(client), nil, "no id field: nothing selected")
        test.assert_deep_eq(properties(client), {})
    end)
end)

test.case("an empty number field refuses the whole apply with a notification: nothing applied, nothing sent, the fields keep their text", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local token = game_client.find_token(client, "Bilbosza")
        local diameter = assert(property_by_key(client, "diameter").input) --[[@as NumberInput]]
        diameter:set_text("")
        assert(property_by_key(client, "name").input):set_text("Bilbo the Great")
        test.assert_deep_eq(apply_id(client, "Bilbo"), {
            "Diameter needs a number"
        })
        test.assert_eq(token:get_id(), "Bilbosza", "not renamed")
        test.assert_eq(token:get_data().diameter, 1)
        test.assert_eq(token:get_data().name, "Bilbosza Wielka")
        test.assert_eq(client.connection:get_out_channel():getCount(), 0)
        test.assert_eq(diameter:get_text(), "")
        test.assert_eq(assert(id_input(client)):get_text(), "Bilbo")
        test.assert_eq(assert(property_by_key(client, "name").input):get_text(), "Bilbo the Great")

        diameter:set_text("2")
        test.assert_deep_eq(apply_id(client, "Bilbo"), {})
        test.assert_eq(token:get_id(), "Bilbo")
        test.assert_eq(token:get_data().diameter, 2)
        test.assert_eq(token:get_data().name, "Bilbo the Great")
    end)
end)

test.case("a multivalue number field left alone does not refuse the apply", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.find_token(client, "Smaug"):set_data("diameter", 3)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        local diameter = assert(property_by_key(client, "diameter").input)
        test.assert_true(diameter:is_multivalue_default())
        local name = assert(property_by_key(client, "name").input)
        name:set_text("Twins")
        name:on_edit("Twins")
        local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
        notifications.messages = {}
        game_client.click(client, assert(apply_button(client)))
        test.assert_deep_eq(notifications.messages, {})
        test.assert_eq(game_client.find_token(client, "Smaug"):get_data().name, "Twins")
        test.assert_eq(game_client.find_token(client, "Smaug"):get_data().diameter, 3)
    end)
end)

test.case("a token property the session hears of is shown for a selected token that has it; a change of another kind rebuilds nothing", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local name_input = assert(property_by_key(client, "name").input)
        client.game_screen:on_entries_change("pages", "P")
        test.assert_eq(property_by_key(client, "name").input, name_input, "the pages are not the token panel's")

        local data = assert(client.app.data)
        data.token_properties.hp = {
            title = "HP",
            type = "number"
        }
        game_client.find_token(client, "Bilbosza"):set_data("hp", 7)
        client.game_screen:on_entries_change("token_properties", "hp")
        local hp = property_by_key(client, "hp")
        test.assert_eq(assert(hp.title):get_text(), "HP")
        local input = assert(hp.input) --[[@as NumberInput]]
        test.assert_eq(input:get_number(), 7)
        test.assert_false(input:is_read_only())
        test.assert_false(lifetime.alive(name_input), "the old fields destroyed")
    end)
end)

test.case("on_grants_change gates the selection by the grants the session holds now", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Smaug"
        })
        assert_inputs_read_only(client, true, "read-only")
        test.assert_eq(apply_button(client), nil)
        client.session:set_grants({
            "read",
            "write:tokens/Smaug"
        })
        client.game_screen:on_grants_change()
        assert_inputs_read_only(client, false, "editable")
        test.assert_true(apply_button(client) ~= nil)
        test.assert_true(delete_button(client) ~= nil)
        test.assert_false(assert(id_input(client)):is_read_only())
    end)
end)

---@param client GameClient
---@return TextButton|nil
local function new_button(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen:get_token_panel()._new_button
end

---@param client GameClient
---@return string[] The captions of the panel's bottom row, left to right
---@return number New's x
local function assert_button_row(client)
    local panel = client.game_screen:get_token_panel()
    local panel_w, panel_h = panel:get_size()
    local s, p = Consts.PANEL_FIELD_SCALE, Consts.PADDING
    ---@type TextButton[]
    local row = {}
    for _, find in ipairs({
        cancel_button,
        new_button,
        delete_button,
        apply_button
    }) do
        local button = find(client)
        if button then
            test.assert_eq(button:get_parent(), panel)
            local _, y, _, h = button:get_position_and_size()
            test.assert_near(y, panel_h - h * s - p, 1e-9, button:get_text() .. " at the panel's bottom")
            table.insert(row, button)
        end
    end
    table.sort(row, function(a, b)
        return a:get_position() < b:get_position()
    end)
    ---@type string[]
    local captions = {}
    for _, button in ipairs(row) do
        table.insert(captions, button:get_text())
    end

    local cancel, new = assert(cancel_button(client)), assert(new_button(client))
    local cancel_x, _, cancel_w = cancel:get_position_and_size()
    test.assert_eq(cancel_x, p, "Cancel at the left edge")
    local new_x, _, new_w = new:get_position_and_size()
    test.assert_near(new_x, cancel_x + cancel_w * s + p, 1e-9, "New a padding right of Cancel")
    local apply = apply_button(client)
    if apply then
        local apply_x, _, apply_w = apply:get_position_and_size()
        test.assert_near(apply_x + apply_w * s, panel_w - p, 1e-9, "Apply at the right edge")
        local delete = delete_button(client)
        if delete then
            local delete_x, _, delete_w = delete:get_position_and_size()
            test.assert_near(delete_x + delete_w * s * 0.5, (new_x + new_w * s + apply_x) * 0.5, 1e-9, "Delete centered between New and Apply")
            test.assert_true(new_x + new_w * s < delete_x and delete_x + delete_w * s < apply_x, "Delete apart from both")
        end
    end
    return captions, new_x
end

test.case("the bottom row reads Cancel, New, Delete and Apply, each in its fixed place; New stays put without a selection and for a read-only one", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local captions, new_x = assert_button_row(client)
        test.assert_deep_eq(captions, {
            "Cancel",
            "New",
            "Delete",
            "Apply"
        })
        game_client.select(client, {})
        local empty_captions, empty_new_x = assert_button_row(client)
        test.assert_deep_eq(empty_captions, {
            "Cancel",
            "New",
            "Apply"
        }, "nothing selected")
        test.assert_eq(empty_new_x, new_x, "New in its place without a selection")
        game_client.select(client, {
            "Smaug"
        })
        local read_only_captions, read_only_new_x = assert_button_row(client)
        test.assert_deep_eq(read_only_captions, {
            "Cancel",
            "New"
        }, "a token the player may not write")
        test.assert_eq(read_only_new_x, new_x, "New in its place for a read-only selection")
    end)
end)

test.case("New shows the new token screen", function()
    with_client({
        "read",
        "write"
    }, function(client)
        local new = assert(new_button(client))
        test.assert_false(new:is_read_only(), "the master writes the tokens")
        game_client.click(client, new)
        test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "NewTokenScreen")
        test.assert_eq(client.app.screen_manager:get_screen(), client.session:get_new_token_screen())
    end)
end)

test.case("New is read-only, dimmed and not clickable, for a player who writes only the tokens they own, with or without a selection", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        for _, ids in ipairs({
            {},
            {
                "Bilbosza"
            }
        }) do
            game_client.select(client, ids)
            local new = assert(new_button(client))
            test.assert_true(new:is_read_only())
            test.assert_deep_eq(new:get_color(), Consts.BUTTON_READ_ONLY_COLOR)
            game_client.click(client, new)
            test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
            test.assert_eq(client.session:get_new_token_screen(), nil)
        end
    end)
end)

test.case("on_grants_change gates New by the grants the session holds now", function()
    with_client({
        "read",
        "write:tokens/@owned"
    }, function(client)
        test.assert_true(assert(new_button(client)):is_read_only())
        client.session:set_grants({
            "read",
            "write:tokens"
        })
        client.game_screen:on_grants_change()
        test.assert_false(assert(new_button(client)):is_read_only())
        client.session:set_grants({
            "read"
        })
        client.game_screen:on_grants_change()
        test.assert_true(assert(new_button(client)):is_read_only())
    end)
end)

test.case("the avatar of one selected token shows under its title and above its path, in a circle of the preview size as on the page", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local avatar = property_by_key(client, "avatar")
        local preview = assert(avatar.preview, "a preview")
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(preview:get_parent(), client.game_screen:get_token_panel()._scroll_view:get_content())
        local size = Consts.TOKEN_PANEL_IMAGE_PREVIEW_SIZE
        test.assert_eq(get_class_name_of(preview), "Avatar")
        test.assert_deep_eq({
            preview:get_size()
        }, {
            size,
            size
        })
        local image = preview --[[@as Avatar]] :get_image()
        test.assert_eq(image:get_parent(), preview)
        local w, h = image:get_size()
        test.assert_near(image:get_scale(), math.max(size / w, size / h), 1e-9, "covering the circle")
        test.assert_deep_eq({
            image:get_position()
        }, {
            size * 0.5,
            size * 0.5
        })
        local _, title_y = assert(avatar.title):get_position()
        local _, title_h = assert(avatar.title):get_size()
        local preview_x, preview_y = preview:get_position()
        test.assert_eq(preview_x, Consts.PADDING)
        test.assert_near(preview_y, title_y + title_h * Consts.PANEL_FIELD_SCALE, 1e-9, "under the title")
        local _, input_y = assert(avatar.input):get_position()
        test.assert_near(input_y, preview_y + size + Consts.PADDING * 0.5, 1e-9, "the input a half padding under the square")
        for _, property in ipairs(properties(client)) do
            if property.key ~= "avatar" then
                test.assert_eq(property.preview, nil, property.key .. " is no image")
            end
        end
    end)
end)

---@param client GameClient
---@param fn fun() Run while `love.graphics.newImage` answers an image of 128 by 32 texels for any file
local function with_wide_image(client, fn)
    local graphics = assert(love.graphics)
    local new_image = graphics.newImage
    assert(love.filesystem.write("c/games/g/assets/token/wide.png", "W"))
    graphics.newImage = function()
        return {
            getDimensions = function()
                return 128, 32
            end,
            setFilter = function()
            end,
            setMipmapFilter = function()
            end
        } --[[@as love.Image]]
    end
    ---@type boolean, any
    local ok, err = pcall(fn)
    graphics.newImage = new_image
    assert(ok, err)
end

test.case("a wide avatar covers its circle by the shorter side, as on the page", function()
    with_client({
        "read",
        "write"
    }, function(client)
        with_wide_image(client, function()
            game_client.find_token(client, "Bilbosza"):set_data("avatar", "token/wide.png")
            game_client.select(client, {
                "Bilbosza"
            })
        end)
        local avatar = property_by_key(client, "avatar")
        local preview = assert(avatar.preview) --[[@as Avatar]]
        local size = Consts.TOKEN_PANEL_IMAGE_PREVIEW_SIZE
        test.assert_near(preview:get_image():get_scale(), size / 32, 1e-9, "by the shorter side")
        local _, preview_y = preview:get_position()
        local _, input_y = assert(avatar.input):get_position()
        test.assert_near(input_y, preview_y + size + Consts.PADDING * 0.5, 1e-9, "the circle's height")
    end)
end)

test.case("another image property shows its image fitted into the square, keeping its aspect, the square's whole height taken", function()
    with_client({
        "read",
        "write"
    }, function(client)
        app.data.token_properties.portrait = {
            title = "Portrait",
            type = "image"
        }
        with_wide_image(client, function()
            game_client.find_token(client, "Bilbosza"):set_data("portrait", "token/wide.png")
            game_client.select(client, {
                "Bilbosza"
            })
        end)
        local portrait = property_by_key(client, "portrait")
        local preview = assert(portrait.preview)
        test.assert_eq(get_class_name_of(preview), "Image")
        local size = Consts.TOKEN_PANEL_IMAGE_PREVIEW_SIZE
        test.assert_near(preview:get_scale(), size / 128, 1e-9, "by the longer side")
        local _, preview_y = preview:get_position()
        local _, input_y = assert(portrait.input):get_position()
        test.assert_near(input_y, preview_y + size + Consts.PADDING * 0.5, 1e-9, "the square's height, not the image's")
    end)
end)

test.case("no preview for a multivalue image property or a path the store has no file for", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza",
            "Smaug"
        })
        test.assert_eq(property_by_key(client, "avatar").preview, nil, "multivalue")
        game_client.find_token(client, "Smaug"):set_data("avatar", "token/missing.png")
        game_client.select(client, {
            "Smaug"
        })
        local avatar = property_by_key(client, "avatar")
        test.assert_eq(avatar.preview, nil, "not in the store")
        local _, title_y = assert(avatar.title):get_position()
        local _, title_h = assert(avatar.title):get_size()
        local _, input_y = assert(avatar.input):get_position()
        test.assert_near(input_y, title_y + title_h * Consts.PANEL_FIELD_SCALE, 1e-9, "the path field right under the title")
    end)
end)

test.case("a rebuild destroys the preview, and an image chosen in the workspace shows the new one", function()
    with_client({
        "read",
        "write"
    }, function(client)
        game_client.select(client, {
            "Bilbosza"
        })
        local preview = assert(property_by_key(client, "avatar").preview)
        local panel = client.game_screen:get_token_panel()
        ---@diagnostic disable-next-line: invisible
        panel:_set_image("avatar", "token/s.png")
        test.assert_false(lifetime.alive(preview), "the old preview destroyed")
        local shown = assert(property_by_key(client, "avatar").preview) --[[@as Avatar]]
        test.assert_true(lifetime.alive(shown))
        test.assert_eq(shown:get_image():get_love_image(), require("graphics.images").get("c/games/g/assets/token/s.png"))
        game_client.select(client, {})
        test.assert_false(lifetime.alive(shown), "destroyed with the selection's properties")
    end)
end)

local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local menu_client = require("tests.lib.menu-client")
local lifetime = require("lifetime")
local media = require("utils.media")

---@param name string
---@param fn fun(client: GameClient, screen: NewTokenScreen)
local function screen_case(name, fn)
    test.case(name, function()
        local client = game_client.enter({
            "read",
            "write"
        })
        client.session:show_new_token()
        local screen = assert(client.session:get_new_token_screen())
        local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
        notifications.messages = {}
        ---@type boolean, any
        local ok, err = pcall(fn, client, screen)
        game_client.finish(client)
        if not ok then
            error(err, 0)
        end
    end)
end

---@param client GameClient
---@return string[] The notifications since the last call
local function notified(client)
    local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
    local messages = notifications.messages
    notifications.messages = {}
    return messages
end

---@param screen NewTokenScreen
---@param index integer 1 for the Id, 2 for the Name, 3 for the Avatar
---@param text string
local function type_into(screen, index, text)
    menu_client.click(menu_client.find_all(screen, "TextInput")[index])
    app.text_event_manager:text_input(text)
end

---@param screen NewTokenScreen
---@param id string
---@param name string
---@param avatar string
local function fill_in(screen, id, name, avatar)
    type_into(screen, 1, id)
    type_into(screen, 2, name)
    type_into(screen, 3, avatar)
end

---@param client GameClient
---@return integer
local function sent_count(client)
    return client.connection:get_out_channel():getCount()
end

test.suite("NewTokenScreen")

screen_case("titled New Token: the fields Id, Name and Avatar, and Browse..., Create and Back", function(client, screen)
    test.assert_eq(client.app.screen_manager:get_screen(), screen)
    test.assert_eq(#menu_client.find_all(screen, "TextInput"), 3)
    test.assert_deep_eq(menu_client.captions(screen), {
        "Browse...",
        "Create",
        "Back"
    })
    test.assert_deep_eq(menu_client.texts(screen), {
        "New Token",
        "Id",
        "Name",
        "Avatar"
    })
end)

screen_case("an id the game refuses, an empty name and an empty avatar are notified, nothing sent", function(client, screen)
    fill_in(screen, "Smaug", "Gandalf", "token/s.png")
    menu_client.click(menu_client.button(screen, "Create"))
    test.assert_deep_eq(notified(client), {
        "A token with the id \"Smaug\" already exists"
    })
    menu_client.click(menu_client.button(screen, "Back"))
    client.session:show_new_token()
    screen = assert(client.session:get_new_token_screen())
    menu_client.click(menu_client.button(screen, "Create"))
    test.assert_deep_eq(notified(client), {
        "An id must not be empty"
    })
    type_into(screen, 1, "Gandalf")
    menu_client.click(menu_client.button(screen, "Create"))
    test.assert_deep_eq(notified(client), {
        "A token needs a name"
    })
    type_into(screen, 2, "Gandalf")
    menu_client.click(menu_client.button(screen, "Create"))
    test.assert_deep_eq(notified(client), {
        "A token needs an avatar"
    })
    test.assert_eq(sent_count(client), 0)
    test.assert_eq(client.app.screen_manager:get_screen(), screen)
end)

screen_case("Create asks for the token at the center of the view on the shown page; the answer closes the screen and the token is on the page", function(client, screen)
    local page = client.game_screen:get_page()
    local x, y = page:get_view_center()
    fill_in(screen, "Gandalf", "Gandalf the Grey", "token/s.png")
    menu_client.click(menu_client.button(screen, "Create"))
    local request = game_client.pop_request(client, "CreateTokenRp") --[[@as CreateTokenRequest]]
    test.assert_eq(request.id, "Gandalf")
    test.assert_eq(request.page, "P")
    local token = request.token
    test.assert_near(token.position[1], x, 1e-6, "at the view's center")
    test.assert_near(token.position[2], y, 1e-6)
    token.position = {
        x,
        y
    }
    test.assert_deep_eq(token, {
        name = "Gandalf the Grey",
        diameter = 1,
        avatar = "token/s.png",
        position = {
            x,
            y
        }
    })
    test.assert_eq(client.app.screen_manager:get_screen(), screen, "open until the answer")
    game_client.answer(client, "CreateTokenRp", {
        success = true,
        id = "Gandalf",
        page = "P",
        token = token
    })
    test.assert_false(lifetime.alive(screen))
    test.assert_eq(client.session:get_new_token_screen(), nil)
    test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
    local token_x, token_y = game_client.find_token(client, "Gandalf"):get_position()
    test.assert_near(token_x, x, 1e-6)
    test.assert_near(token_y, y, 1e-6)
    test.assert_deep_eq(notified(client), {})
end)

screen_case("Enter in a field creates the token", function(client, screen)
    fill_in(screen, "Gandalf", "Gandalf", "token/s.png")
    app.text_event_manager:key_pressed("return")
    local request = game_client.pop_request(client, "CreateTokenRp") --[[@as CreateTokenRequest]]
    test.assert_eq(request.id, "Gandalf")
end)

screen_case("a refusal is notified and the screen stays", function(client, screen)
    fill_in(screen, "Gandalf", "Gandalf", "token/x.png")
    menu_client.click(menu_client.button(screen, "Create"))
    game_client.pop_request(client, "CreateTokenRp")
    game_client.answer(client, "CreateTokenRp", {
        success = false,
        error = "No asset \"token/x.png\"",
        id = "Gandalf",
        page = "P"
    })
    test.assert_deep_eq(notified(client), {
        "No asset \"token/x.png\""
    })
    test.assert_true(lifetime.alive(screen))
    test.assert_eq(client.app.screen_manager:get_screen(), screen)
    test.assert_eq(client.game_screen:get_page():try_find_token("Gandalf"), nil)
end)

screen_case("Back shows the game again and destroys the screen", function(client, screen)
    menu_client.click(menu_client.button(screen, "Back"))
    test.assert_false(lifetime.alive(screen))
    test.assert_eq(client.session:get_new_token_screen(), nil)
    test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
    client.app.backstack_manager:back()
    test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "UserMenuScreen", "the game's own entry was next")
end)

screen_case("Browse... opens the assets workspace to pick an image, and the pick fills the Avatar field", function(client, screen)
    menu_client.click(menu_client.button(screen, "Browse..."))
    local workspace = client.app.screen_manager:get_screen() --[[@as AssetsWorkspaceScreen]]
    test.assert_eq(get_class_name_of(workspace), "AssetsWorkspaceScreen")
    game_client.pop_request(client, "ListAssetsRp")
    ---@diagnostic disable-next-line: invisible
    local pick = assert(workspace._pick)
    test.assert_eq(pick.path, nil, "nothing typed, nothing shown selected")
    test.assert_eq(pick.media_type, media.Type.IMAGE)
    client.session:close_assets_workspace()
    test.assert_eq(client.app.screen_manager:get_screen(), screen, "back to the screen it was opened from")
    assert(pick.on_pick)("token/b.png")
    local avatar = menu_client.find_all(screen, "TextInput")[3] --[[@as TextInput]]
    test.assert_eq(avatar:get_text(), "token/b.png")

    menu_client.click(menu_client.button(screen, "Browse..."))
    workspace = client.app.screen_manager:get_screen() --[[@as AssetsWorkspaceScreen]]
    game_client.pop_request(client, "ListAssetsRp")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(assert(workspace._pick).path, "token/b.png", "the typed avatar shown selected")
    client.session:close_assets_workspace()
end)

screen_case("leaving the game destroys an open new token screen", function(client, screen)
    client.session:leave_game()
    test.assert_false(lifetime.alive(screen))
    test.assert_eq(client.session:get_new_token_screen(), nil)
    test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "UserMenuScreen")
end)

local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")

---@param name string
---@param fn fun(client: GameClient)
local function client_case(name, fn)
    test.case(name, function()
        local client = game_client.enter({
            "read"
        })
        local notifications = client.app.notification_manager --[[@as TestNotificationManager]]
        notifications.messages = {}
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
---@param name string
local function push(client, id, name)
    ---@type Request
    local request = {
        source = "s",
        id = "GameDeletedRp",
        body = {
            id = id,
            name = name
        }
    }
    client.connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(request)))
    app = client.app
    client.app.update_event:trigger(0.016)
end

test.suite("GameDeletedRp")

client_case("a client in the game is sent to the menu with the notification, its data, grants, store and copies dropped, and acknowledges with nothing", function(client)
    local game_screen = client.game_screen
    push(client, mocks.GAME_ID, "Meadow")
    test.assert_deep_eq(game_client.pop_request(client, "GameDeletedRp"), {})
    local notifications = client.app.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "The game \"Meadow\" was deleted"
    })
    test.assert_false(lifetime.alive(game_screen))
    test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "UserMenuScreen")
    test.assert_eq(client.session:get_game_screen(), nil)
    test.assert_eq(client.app.data, nil)
    test.assert_eq(client.session:get_game_id(), nil)
    test.assert_eq(client.app.asset_manager:get_store(), nil)
    test.assert_eq(love.filesystem.getInfo("c/games/" .. mocks.GAME_ID), nil)
    test.assert_false(client.session:is_allowed("read"))
    client.app.backstack_manager:back()
    test.assert_eq(type(game_client.pop_request(client, "LogoutRp")), "table", "the game's entry went with the screen: the next back logs out")
end)

client_case("a client back on the menu drops the game's data without a screen change; another game's deletion is only notified", function(client)
    client.app.backstack_manager:back()
    local menu = client.app.screen_manager:get_screen()
    push(client, "other", "Other")
    local notifications = client.app.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "The game \"Other\" was deleted"
    })
    test.assert_eq(client.app.data ~= nil, true, "the data of the game the client holds stays")
    test.assert_eq(client.session:get_game_id(), mocks.GAME_ID)
    push(client, mocks.GAME_ID, "Meadow")
    test.assert_eq(notifications.messages[2], "The game \"Meadow\" was deleted")
    test.assert_eq(client.app.data, nil)
    test.assert_eq(client.app.asset_manager:get_store(), nil)
    test.assert_eq(client.app.screen_manager:get_screen(), menu)
end)

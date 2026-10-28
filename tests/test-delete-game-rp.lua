local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local game_client = require("tests.lib.game-client")
local lifetime = require("lifetime")

---@return GameData
local function game_data()
    return {
        name = "Meadow",
        game = {
            page = "P"
        },
        groups = {
            master = {
                title = "Game master",
                permissions = {
                    "read",
                    "write"
                }
            },
            player = {
                title = "Player",
                permissions = {
                    "read"
                }
            }
        },
        players = {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player"
            }
        },
        pages = {
            P = {
                name = "P",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {}
            }
        },
        token_properties = {},
        tokens = {}
    }
end

---@return string
local function other_save()
    local data = game_data()
    data.name = "Other"
    data.players = {
        ewa = {
            group = "master"
        }
    }
    return table.to_string(data)
end

---@param side TestServerSide
---@param id string
---@return DeleteGameResponse
local function delete(side, id)
    return mocks.request(side.connection, "DeleteGameRp", {
        id = id
    }) --[[@as DeleteGameResponse]]
end

test.suite("DeleteGameRp")

test.case("refused before the login, for a game that is not there, for a player without write on the game and for a game the user is not in", function()
    local side = mocks.make_server_session(game_data, {
        ["s/games/other/save.lua"] = other_save()
    })
    test.assert_deep_eq(delete(side, mocks.GAME_ID), {
        success = false,
        error = "Not logged in"
    })
    test.assert_eq(mocks.log_in(side.connection, "piotr"), "piotr")
    test.assert_deep_eq(delete(side, "zzz"), {
        success = false,
        error = "No such game"
    })
    test.assert_deep_eq(delete(side, mocks.GAME_ID), {
        success = false,
        error = "You may not delete the game \"Meadow\""
    })
    test.assert_deep_eq(delete(side, "other"), {
        success = false,
        error = "You may not delete the game \"Other\""
    })
    test.assert_deep_eq(assert(side.server.games):list(), {
        mocks.GAME_ID,
        "other"
    }, "nothing deleted")
    mocks.finish_server_session(side)
end)

test.case("a master deletes the game: every session in it leaves it, the others are told, the directory goes", function()
    local side = mocks.make_server_session(game_data, {
        ["s/games/" .. mocks.GAME_ID .. "/assets/world/w.png"] = "W",
        ["s/games/other/save.lua"] = other_save()
    })
    ---@type boolean, any
    local ok, err = pcall(function()
        mocks.join_game(side.connection, "adam")
        local piotr_connection, piotr = mocks.join_another("piotr")
        test.assert_deep_eq(delete(side, mocks.GAME_ID), {
            success = true,
            id = mocks.GAME_ID,
            name = "Meadow"
        })
        test.assert_false(side.session:is_in_game())
        test.assert_false(piotr:is_in_game())
        test.assert_deep_eq(mocks.sent(side.connection), {}, "the deleter gets the answer, no push")
        local pushed = mocks.sent(piotr_connection)
        test.assert_eq(#pushed, 1)
        test.assert_eq(pushed[1].id, "GameDeletedRp")
        test.assert_deep_eq(pushed[1].body, {
            id = mocks.GAME_ID,
            name = "Meadow"
        })
        local games = assert(side.server.games)
        test.assert_eq(games:get(mocks.GAME_ID), nil)
        test.assert_eq(love.filesystem.getInfo("s/games/" .. mocks.GAME_ID), nil, "the directory with the save and the store")
        test.assert_deep_eq(games:list(), {
            "other"
        })
        test.assert_deep_eq(delete(side, mocks.GAME_ID), {
            success = false,
            error = "No such game"
        })
        lifetime.destroy(piotr_connection)
    end)
    mocks.finish_server_session(side)
    if not ok then
        error(err, 0)
    end
end)

---@param name string
---@param fn fun(client: GameClient)
local function client_case(name, fn)
    test.case(name, function()
        local client = game_client.enter({
            "read",
            "write"
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

---@param client GameClient Back on the menu, Games, Delete Game with its listing in, and the question about the game opened
---@return Screen The games to delete
---@return Screen The question
local function open_delete_game(client)
    client.app.backstack_manager:back()
    test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "UserMenuScreen")
    client.session:show_games_menu()
    client.session:show_delete_game()
    test.assert_deep_eq(game_client.pop_request(client, "ListGamesRp"), {})
    game_client.answer(client, "ListGamesRp", {
        games = {
            {
                id = mocks.GAME_ID,
                name = "Meadow",
                member = true,
                deletable = true
            },
            {
                id = "other",
                name = "Other",
                member = false,
                deletable = false
            }
        }
    })
    local list = assert(client.app.screen_manager:get_screen())
    test.assert_eq(get_class_name_of(list), "DeleteGameScreen")
    client.session:confirm_delete_game(mocks.GAME_ID, "Meadow")
    local question = assert(client.app.screen_manager:get_screen())
    test.assert_eq(get_class_name_of(question), "ConfirmDeleteGameScreen")
    return list, question
end

client_case("the client: a deletion the server accepted is notified, drops the game's data and its copies, and closes the question and the list over Games", function(client)
    local list, question = open_delete_game(client)
    client.session:delete_game(mocks.GAME_ID)
    test.assert_deep_eq(game_client.pop_request(client, "DeleteGameRp"), {
        id = mocks.GAME_ID
    })
    game_client.answer(client, "DeleteGameRp", {
        success = true,
        id = mocks.GAME_ID,
        name = "Meadow"
    })
    local notifications = client.app.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "The game \"Meadow\" was deleted"
    })
    test.assert_eq(client.app.data, nil)
    test.assert_eq(client.session:get_game_id(), nil)
    test.assert_eq(client.app.asset_manager:get_store(), nil)
    test.assert_eq(love.filesystem.getInfo("c/games/" .. mocks.GAME_ID), nil, "the client's copies")
    test.assert_false(lifetime.alive(question))
    test.assert_false(lifetime.alive(list))
    test.assert_eq(get_class_name_of(client.app.screen_manager:get_screen()), "GamesMenuScreen")
end)

client_case("the client: a refusal is notified and the question stays, the data kept", function(client)
    local _, question = open_delete_game(client)
    client.session:delete_game("other")
    game_client.pop_request(client, "DeleteGameRp")
    game_client.answer(client, "DeleteGameRp", {
        success = false,
        error = "You may not delete the game \"Other\""
    })
    local notifications = client.app.notification_manager --[[@as TestNotificationManager]]
    test.assert_deep_eq(notifications.messages, {
        "You may not delete the game \"Other\""
    })
    test.assert_eq(client.app.data ~= nil, true)
    test.assert_eq(client.session:get_game_id(), mocks.GAME_ID)
    test.assert_eq(client.app.screen_manager:get_screen(), question)
end)

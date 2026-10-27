local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local entries = require("game.entry.entries")

---@param name string
---@param fn fun(side: TestClientSide, screen: TestGameScreen)
local function client_case(name, fn)
    test.case(name, function()
        local side = mocks.make_client_session({
            ["c/games/g/assets/world/w.png"] = "W",
            ["c/games/g/assets/token/t.png"] = "T"
        })
        mocks.join_client_game(side, "piotr", mocks.entries_game_data(), {
            "read",
            "write:pages/P"
        })
        local screen = mocks.make_game_screen()
        ---@diagnostic disable-next-line: invisible
        side.session._game_screen = screen
        ---@type boolean, any
        local ok, err = pcall(fn, side, screen)
        mocks.finish_client_session(side)
        if not ok then
            error(err, 0)
        end
    end)
end

---@param side TestClientSide
---@param body RequestBody
---@return Request[] What the client sent besides the acknowledgement, which is empty
local function push(side, body)
    mocks.deliver(side.connection, "EntryChangedRp", body)
    ---@type Request[]
    local others = {}
    local acknowledged = 0
    for _, sent in ipairs(mocks.sent(side.connection)) do
        if sent.id == "EntryChangedRp" then
            test.assert_deep_eq(sent.body, {})
            acknowledged = acknowledged + 1
        else
            table.insert(others, sent)
        end
    end
    test.assert_eq(acknowledged, 1)
    return others
end

test.suite("EntryChangedRp")

client_case("a change is applied to the data and the game screen told", function(side, screen)
    push(side, {
        kind = "groups",
        id = "player",
        entry = {
            title = "Players",
            permissions = {
                "read"
            }
        }
    })
    test.assert_deep_eq(assert(side.client.data).groups.player, {
        title = "Players",
        permissions = {
            "read"
        }
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change groups player"
    })
end)

client_case("a rename renames the key, what names it and the set's grants, and tells the game screen the new id", function(side, screen)
    local entry = mocks.entries_game_data().pages.P
    entry.tokens = {}
    push(side, {
        kind = "pages",
        id = "P",
        new_id = "R",
        entry = entry
    })
    local data = assert(side.client.data)
    test.assert_eq(data.pages.P, nil)
    test.assert_deep_eq(data.pages.R.tokens, {
        "T"
    }, "the tokens as the client holds them")
    test.assert_eq(data.game.page, "R")
    test.assert_deep_eq(data.players.piotr.permissions, {
        "write:pages/R"
    })
    test.assert_deep_eq(side.session:get_permissions():get_grants(), {
        "read",
        "write:pages/R"
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages R"
    }, "the image, the width and the scale as they were: the page stays")
end)

client_case("a rename the client's data refuses is logged, and the fields are applied under the id it holds", function(side, screen)
    local entry = mocks.entries_game_data().pages.Q
    entry.name = "Quarry Pit"
    push(side, {
        kind = "pages",
        id = "Q",
        new_id = "P",
        entry = entry
    })
    test.assert_deep_eq(side.client.logs[#side.client.logs], {
        "The page \"Q\" is not renamed to \"P\": A page with the id \"P\" already exists"
    })
    local data = assert(side.client.data)
    test.assert_eq(data.pages.Q.name, "Quarry Pit")
    test.assert_eq(data.pages.P.name, "Plains")
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages Q"
    })
end)

client_case("an entry the client does not hold, or of a kind it does not know, is logged and ignored", function(side, screen)
    push(side, {
        kind = "pages",
        id = "Z",
        entry = mocks.entries_game_data().pages.P
    })
    test.assert_deep_eq(side.client.logs[#side.client.logs], {
        "A change of the page \"Z\", which this client does not hold, ignored"
    })
    push(side, {
        kind = "tokens",
        id = "T",
        entry = mocks.entries_game_data().pages.P
    })
    test.assert_deep_eq(side.client.logs[#side.client.logs], {
        "A change of the entry \"T\" of the unknown kind \"tokens\", which this client does not hold, ignored"
    })
    test.assert_deep_eq(side.client.data, mocks.entries_game_data())
    test.assert_deep_eq(screen.calls, {})
end)

client_case("the game's page changed to one whose assets are in shows it at once", function(side, screen)
    test.assert_deep_eq(push(side, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "Q"
        }
    }), {}, "nothing to download")
    test.assert_eq(assert(side.client.data).game.page, "Q")
    test.assert_deep_eq(screen.calls, {
        "show_page Q",
        "on_entries_change game game"
    })
end)

client_case("the game's page changed to one whose assets the store lacks shows it once they are in, unless the page changed again", function(side, screen)
    local data = assert(side.client.data)
    data.pages.Q.image = "world/q.png"
    local sent = push(side, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "Q"
        }
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change game game"
    })
    test.assert_eq(#sent, 1)
    test.assert_eq(sent[1].id, "DownloadMissingAssetsRp")
    test.assert_deep_eq(sent[1].body, {
        list = {
            "world/q.png"
        }
    })
    mocks.answer(side.connection, "DownloadMissingAssetsRp", {
        success = true,
        contents = {
            ["world/q.png"] = love.data.encode("string", "base64", "Q")
        }
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change game game",
        "show_page Q"
    })
    test.assert_eq(love.filesystem.read("c/games/g/assets/world/q.png"), "Q")

    screen.calls = {}
    data.pages.P.image = "world/p.png"
    test.assert_eq(#push(side, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "P"
        }
    }), 1, "the download of P's image")
    push(side, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "Q"
        }
    })
    mocks.answer(side.connection, "DownloadMissingAssetsRp", {
        success = true,
        contents = {}
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change game game",
        "show_page Q",
        "on_entries_change game game"
    }, "Q at once, P not after its download: the game shows Q by then")
end)

client_case("the game's page changed to one the client does not hold leaves the game with a notification", function(side, screen)
    local calls = screen.calls
    push(side, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "Secret"
        }
    })
    test.assert_deep_eq(side.notifications.messages, {
        "Nothing to show: no page you may see"
    })
    test.assert_eq(assert(side.client.data).game.page, "Secret")
    test.assert_deep_eq(calls, {})
    test.assert_false(lifetime.alive(screen))
    test.assert_eq(side.session:get_game_screen(), nil)
    test.assert_eq(get_class_name_of(side.client.screen_manager:get_screen()), "UserMenuScreen")
end)

client_case("the shown page's image, width or scale changed shows it again; its name alone does not", function(side, screen)
    local entry = mocks.entries_game_data().pages.P
    entry.name = "Pastures"
    push(side, {
        kind = "pages",
        id = "P",
        entry = entry
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages P"
    })
    entry = mocks.entries_game_data().pages.P
    entry.width = 20
    push(side, {
        kind = "pages",
        id = "P",
        entry = entry
    })
    test.assert_eq(assert(side.client.data).pages.P.width, 20)
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages P",
        "show_page P",
        "on_entries_change pages P"
    })
    screen.calls = {}
    entry = mocks.entries_game_data().pages.Q
    entry.width = 50
    push(side, {
        kind = "pages",
        id = "Q",
        entry = entry
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages Q"
    }, "a page not shown")
end)

client_case("the shown page's image the store lacks is downloaded before the page is shown again", function(side, screen)
    local entry = mocks.entries_game_data().pages.P
    entry.image = "world/n.png"
    local sent = push(side, {
        kind = "pages",
        id = "P",
        entry = entry
    })
    test.assert_eq(#sent, 1)
    test.assert_deep_eq(sent[1].body, {
        list = {
            "world/n.png"
        }
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages P"
    })
    mocks.answer(side.connection, "DownloadMissingAssetsRp", {
        success = true,
        contents = {
            ["world/n.png"] = love.data.encode("string", "base64", "N")
        }
    })
    test.assert_deep_eq(screen.calls, {
        "on_entries_change pages P",
        "show_page P"
    })
end)

client_case("a change pushed after the game was left goes to the data only", function(side, screen)
    local calls = screen.calls
    side.session:leave_game()
    test.assert_false(lifetime.alive(screen))
    test.assert_deep_eq(push(side, {
        kind = "game",
        id = entries.GAME_ID,
        entry = {
            page = "Q"
        }
    }), {}, "nothing downloaded for a game not shown")
    test.assert_eq(assert(side.client.data).game.page, "Q")
    test.assert_deep_eq(calls, {})
end)

test.suite("EntryChangedRp, the server")

test.case("a push a client sends to the server is logged, acknowledged with nothing and changes nothing", function()
    ---@type table<string, string>
    local files = {
        ["s/games/g/assets/world/w.png"] = "W"
    }
    local side = mocks.make_server_session(mocks.entries_game_data, files)
    ---@type boolean, any
    local ok, err = pcall(function()
        mocks.join_game(side.connection, "adam")
        local before = files["s/games/g/save.lua"]
        local response = mocks.request(side.connection, "EntryChangedRp", {
            kind = "pages",
            id = "P",
            new_id = "R",
            entry = mocks.entries_game_data().pages.P
        })
        test.assert_deep_eq(response, {})
        test.assert_deep_eq(side.server.logs[#side.server.logs], {
            "EntryChangedRp is the server's to send: a request from the client ignored"
        })
        test.assert_eq(files["s/games/g/save.lua"], before)
    end)
    mocks.finish_server_session(side)
    if not ok then
        error(err, 0)
    end
end)

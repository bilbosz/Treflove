local test = require("tests.lib.test")
local token_id = require("game.token.token-id")

---@param name string
---@return TokenData
local function token_data(name)
    return {
        name = name,
        diameter = 1,
        avatar = "token/" .. name .. ".png",
        position = {
            0,
            0
        }
    }
end

---@return GameData
local function game_data()
    return {
        game = {
            page = "Old Town"
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
                    "read",
                    "write:tokens/Bilbosz",
                    "write:tokens/@owned",
                    "read:pages/Bilbosz"
                }
            }
        },
        pages = {
            ["Old Town"] = {
                name = "Old Town",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "Gaben",
                    "Bilbosz",
                    "Anonim"
                }
            },
            ["Bilbosz"] = {
                name = "Bilbosz's house",
                width = 10,
                pixel_per_meter = 50,
                image = "world/h.png",
                tokens = {
                    "Bilbosz",
                    "Gaben"
                }
            },
            ["Cave"] = {
                name = "Cave",
                width = 10,
                pixel_per_meter = 50,
                image = "world/c.png",
                tokens = {
                    "Anonim"
                }
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            }
        },
        tokens = {
            Bilbosz = token_data("Bilbosz"),
            Gaben = token_data("Gaben"),
            Anonim = token_data("Anonim")
        },
        players = {
            adam = {
                name = "Adam",
                auth = "adam's hash",
                group = "master"
            },
            piotr = {
                name = "Piotrek",
                auth = "piotr's hash",
                group = "player",
                permissions = {
                    "view:tokens/Bilbosz",
                    "view:tokens/Gaben"
                }
            }
        }
    }
end

test.suite("token_id")

test.case("check refuses an empty id, then one starting with @, then a taken one", function()
    local data = game_data()
    data.tokens["@x"] = token_data("@x")
    test.assert_eq(token_id.check(data, ""), "An id must not be empty")
    test.assert_eq(token_id.check(data, "@x"), "An id must not start with \"@\"")
    test.assert_eq(token_id.check(data, "@owned"), "An id must not start with \"@\"")
    test.assert_eq(token_id.check(data, "Gaben"), "A token with the id \"Gaben\" already exists")
end)

test.case("check accepts a free id, / and : included", function()
    local data = game_data()
    test.assert_eq(token_id.check(data, "Bilbo"), nil)
    test.assert_eq(token_id.check(data, "a/b:c"), nil)
    test.assert_eq(token_id.check(data, "x@"), nil)
end)

test.case("rename moves the entry, the same table, under the new id", function()
    local data = game_data()
    local entry = data.tokens.Bilbosz
    token_id.rename(data, "Bilbosz", "Bilbo")
    test.assert_eq(data.tokens.Bilbo, entry, "the same table")
    test.assert_eq(data.tokens.Bilbosz, nil)
    test.assert_deep_eq(data.tokens.Gaben, token_data("Gaben"))
end)

test.case("rename renames the token in every page's list, the other entries in their order", function()
    local data = game_data()
    token_id.rename(data, "Bilbosz", "Bilbo")
    test.assert_deep_eq(data.pages["Old Town"].tokens, {
        "Gaben",
        "Bilbo",
        "Anonim"
    })
    test.assert_deep_eq(data.pages["Bilbosz"].tokens, {
        "Bilbo",
        "Gaben"
    })
    test.assert_deep_eq(data.pages["Cave"].tokens, {
        "Anonim"
    })
end)

test.case("rename renames the grants on the token, of the groups and the players, and keeps the rest", function()
    local data = game_data()
    token_id.rename(data, "Bilbosz", "Bilbo")
    test.assert_deep_eq(data.groups.master.permissions, {
        "read",
        "write"
    })
    test.assert_deep_eq(data.groups.player.permissions, {
        "read",
        "write:tokens/Bilbo",
        "write:tokens/@owned",
        "read:pages/Bilbosz"
    })
    test.assert_deep_eq(data.players.piotr.permissions, {
        "view:tokens/Bilbo",
        "view:tokens/Gaben"
    })
    test.assert_eq(data.players.adam.permissions, nil, "a player without grants of its own stays without")
end)

test.case("rename works on the client's filtered copy, with no groups and no players", function()
    local data = game_data()
    data.groups = {}
    data.players = {}
    token_id.rename(data, "Gaben", "Gabe")
    test.assert_true(data.tokens.Gabe ~= nil)
    test.assert_eq(data.tokens.Gaben, nil)
    test.assert_deep_eq(data.groups, {})
    test.assert_deep_eq(data.players, {})
end)

test.case("rename raises for an absent id and for a taken new id", function()
    local data = game_data()
    test.assert_error(function()
        token_id.rename(data, "Smaug", "Bilbo")
    end, "an absent id")
    test.assert_error(function()
        token_id.rename(data, "Bilbosz", "Gaben")
    end, "a taken id")
    test.assert_deep_eq(data, game_data(), "nothing changed")
end)

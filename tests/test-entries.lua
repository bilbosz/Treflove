local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local AssetStore = require("data.asset-store")
local entries = require("game.entry.entries")

---@return GameData
local function game_data()
    return {
        name = "G",
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
                    "read:pages/P",
                    "write:groups/player",
                    "read:token_properties/hp"
                }
            },
            empty = {
                title = "Empty",
                permissions = {}
            }
        },
        players = {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player",
                permissions = {
                    "write:pages/P",
                    "write:token_properties/hp"
                }
            }
        },
        pages = {
            P = {
                name = "Plains",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "T"
                }
            },
            Q = {
                name = "Quarry",
                width = 5,
                pixel_per_meter = 20,
                image = "world/q.png",
                tokens = {}
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            },
            diameter = {
                title = "Diameter",
                type = "number"
            },
            avatar = {
                title = "Avatar",
                type = "image"
            },
            position = {
                title = "Position",
                type = "array"
            },
            hp = {
                title = "HP",
                type = "number"
            },
            notes = {
                title = "Notes",
                type = "string"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 1,
                avatar = "token/t.png",
                position = {
                    1,
                    2
                },
                hp = 3
            }
        }
    }
end

---@param fn fun(store: AssetStore)
local function with_store(fn)
    local previous = mocks.install_love_filesystem({
        ["s/games/g/assets/world/w.png"] = "W",
        ["s/games/g/assets/world/n.png"] = "N"
    })
    ---@type boolean, any
    local ok, err = pcall(fn, AssetStore("s/games/g"))
    mocks.restore_love_filesystem(previous)
    if not ok then
        error(err, 0)
    end
end

---@param fields EntryField[]
---@return string[]
local function keys_of(fields)
    ---@type string[]
    local keys = {}
    for _, field in ipairs(fields) do
        table.insert(keys, field.key .. ":" .. field.type)
    end
    return keys
end

test.suite("entries")

test.case("the kinds, their fields in the panels' order, and which kinds are created, deleted and renamed", function()
    test.assert_deep_eq(entries.KINDS, {
        "game",
        "pages",
        "groups",
        "players",
        "token_properties"
    })
    test.assert_deep_eq(keys_of(entries.FIELDS.game), {
        "page:page"
    })
    test.assert_deep_eq(keys_of(entries.FIELDS.pages), {
        "name:string",
        "width:number",
        "pixel_per_meter:number",
        "image:image"
    })
    test.assert_deep_eq(keys_of(entries.FIELDS.groups), {
        "title:string",
        "permissions:grants"
    })
    test.assert_deep_eq(keys_of(entries.FIELDS.players), {
        "group:group",
        "permissions:grants"
    })
    test.assert_deep_eq(keys_of(entries.FIELDS.token_properties), {
        "title:string",
        "type:enum"
    })
    test.assert_deep_eq(assert(entries.find_field("token_properties", "type")).options, {
        "string",
        "number",
        "image",
        "array"
    })
    test.assert_eq(entries.find_field("pages", "tokens"), nil)
    for _, kind in ipairs(entries.KINDS) do
        local changeable = kind == "pages" or kind == "groups" or kind == "token_properties"
        test.assert_eq(entries.can_create(kind), changeable, kind)
        test.assert_eq(entries.can_delete(kind), changeable, kind)
        test.assert_eq(entries.can_rename(kind), changeable, kind)
        test.assert_eq(entries.get_permission_kind(kind), kind, "the grants name the kind by the same string")
        test.assert_true(entries.is_kind(kind))
    end
    test.assert_false(entries.is_kind("tokens"), "tokens have procedures of their own")
    test.assert_false(entries.is_kind("assets"))
end)

test.case("list gives the ids sorted, the game its one id; get finds an entry by its id", function()
    local data = game_data()
    test.assert_deep_eq(entries.list(data, "pages"), {
        "P",
        "Q"
    })
    test.assert_deep_eq(entries.list(data, "groups"), {
        "empty",
        "master",
        "player"
    })
    test.assert_deep_eq(entries.list(data, "players"), {
        "adam",
        "piotr"
    })
    test.assert_deep_eq(entries.list(data, "game"), {
        entries.GAME_ID
    })
    test.assert_eq(entries.get(data, "pages", "Q"), data.pages.Q)
    test.assert_eq(entries.get(data, "game", entries.GAME_ID), data.game)
    test.assert_eq(entries.get(data, "game", "P"), nil)
    test.assert_eq(entries.get(data, "groups", "nobody"), nil)
    data.groups = nil
    test.assert_deep_eq(entries.list(data, "groups"), {}, "a save without the collection lists nothing")
    test.assert_eq(entries.get(data, "groups", "master"), nil)
end)

test.case("check_id refuses what a token id refuses, a taken id of the kind, and the kinds that are never created", function()
    local data = game_data()
    test.assert_eq(entries.check_id(data, "pages", "R"), nil)
    test.assert_eq(entries.check_id(data, "groups", "P"), nil, "an id is the kind's own")
    test.assert_eq(entries.check_id(data, "pages", ""), "An id must not be empty")
    test.assert_eq(entries.check_id(data, "pages", "@owned"), "An id must not start with \"@\"")
    test.assert_eq(entries.check_id(data, "pages", "Q"), "A page with the id \"Q\" already exists")
    test.assert_eq(entries.check_id(data, "token_properties", "hp"), "A token property with the id \"hp\" already exists")
    ---@diagnostic disable-next-line: param-type-mismatch
    test.assert_eq(entries.check_id(data, "groups", 5), "An id must be a string")
    test.assert_eq(entries.check_id(data, "players", "ewa"), "Players cannot be created")
    test.assert_eq(entries.check_id(data, "game", "other"), "The game cannot be created")
end)

test.case("check_changes accepts the fields of the kind with values of their type", function()
    with_store(function(store)
        local data = game_data()
        test.assert_eq(entries.check_changes(data, "pages", "P", {
            name = "Pastures",
            width = 12.5,
            pixel_per_meter = 4,
            image = "world/n.png"
        }, store), nil)
        test.assert_eq(entries.check_changes(data, "pages", "P", {}, store), nil)
        test.assert_eq(entries.check_changes(data, "game", entries.GAME_ID, {
            page = "Q"
        }), nil)
        test.assert_eq(entries.check_changes(data, "groups", "player", {
            title = "Players",
            permissions = {
                "read",
                "write:tokens/@owned",
                "view:tokens/T"
            }
        }), nil)
        test.assert_eq(entries.check_changes(data, "players", "piotr", {
            group = "empty",
            permissions = {}
        }), nil, "an empty list clears the player's own grants")
        test.assert_eq(entries.check_changes(data, "token_properties", "notes", {
            title = "Remarks",
            type = "array"
        }), nil, "no token holds notes")
        test.assert_eq(entries.check_changes(data, "token_properties", "hp", {
            type = "number"
        }), nil, "the type as it is is no change")
        test.assert_eq(entries.check_changes(data, "pages", "P", {
            image = "world/none.png"
        }), nil, "without a store an image is any path")
    end)
end)

test.case("check_changes refuses a key that is not a field, a value of the wrong type, an unknown reference, an empty required string", function()
    with_store(function(store)
        local data = game_data()
        ---@type {kind: EntryKind, id: string, changes: EntryValues, reason: string}[]
        local refused = {
            {
                kind = "pages",
                id = "P",
                changes = {
                    tokens = {}
                },
                reason = "Cannot change \"tokens\" of the page \"P\""
            },
            {
                kind = "game",
                id = entries.GAME_ID,
                changes = {
                    name = "X"
                },
                reason = "Cannot change \"name\" of the game"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    name = 5
                },
                reason = "Name must be a string"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    name = ""
                },
                reason = "Name must not be empty"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    width = "wide"
                },
                reason = "Width must be a positive number"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    width = 0
                },
                reason = "Width must be a positive number"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    pixel_per_meter = -1
                },
                reason = "Pixels per meter must be a positive number"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    pixel_per_meter = math.huge
                },
                reason = "Pixels per meter must be a positive number"
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    image = "world"
                },
                reason = "No asset \"world\""
            },
            {
                kind = "pages",
                id = "P",
                changes = {
                    image = "world/none.png"
                },
                reason = "No asset \"world/none.png\""
            },
            {
                kind = "game",
                id = entries.GAME_ID,
                changes = {
                    page = "R"
                },
                reason = "No page \"R\""
            },
            {
                kind = "players",
                id = "piotr",
                changes = {
                    group = "nobody"
                },
                reason = "No group \"nobody\""
            },
            {
                kind = "groups",
                id = "player",
                changes = {
                    permissions = "read"
                },
                reason = "Permissions must be a list of grants"
            },
            {
                kind = "groups",
                id = "player",
                changes = {
                    permissions = {
                        "read",
                        "fly"
                    }
                },
                reason = "Malformed grant \"fly\": unknown action"
            },
            {
                kind = "players",
                id = "piotr",
                changes = {
                    permissions = {
                        "write:tokens/@mine"
                    }
                },
                reason = "Malformed grant \"write:tokens/@mine\": unknown selector"
            },
            {
                kind = "token_properties",
                id = "notes",
                changes = {
                    type = "date"
                },
                reason = "Type must be one of string, number, image, array"
            },
            {
                kind = "groups",
                id = "player",
                changes = {
                    title = ""
                },
                reason = "Title must not be empty"
            }
        }
        for _, case in ipairs(refused) do
            test.assert_eq(entries.check_changes(data, case.kind, case.id, case.changes, store), case.reason, case.reason)
        end
        test.assert_deep_eq(data, game_data(), "a check changes nothing")
    end)
end)

test.case("check_changes refuses a token property's type changed while a token holds the key, or at all for a property every token has", function()
    local data = game_data()
    test.assert_eq(entries.check_changes(data, "token_properties", "hp", {
        type = "string"
    }), "The type of \"hp\" cannot change while a token holds it")
    test.assert_eq(entries.check_changes(data, "token_properties", "diameter", {
        type = "string"
    }), "\"diameter\" is a property every token has: its type cannot change")
    test.assert_eq(entries.check_changes(data, "token_properties", "diameter", {
        title = "Size"
    }), nil, "its title changes")
    data.tokens.T.hp = nil
    test.assert_eq(entries.check_changes(data, "token_properties", "hp", {
        type = "string"
    }), nil, "held by no token any more")
end)

test.case("check_new needs the required fields, in the table's order, then checks the values; a group's grants default", function()
    with_store(function(store)
        local data = game_data()
        test.assert_eq(entries.check_new(data, "pages", {
            name = "Room",
            width = 4,
            pixel_per_meter = 10,
            image = "world/n.png"
        }, store), nil)
        test.assert_eq(entries.check_new(data, "pages", {
            width = 4,
            image = "world/n.png"
        }, store), "A new page needs \"name\"")
        test.assert_eq(entries.check_new(data, "pages", {
            name = "Room",
            width = 4,
            image = "world/n.png"
        }, store), "A new page needs \"pixel_per_meter\"")
        test.assert_eq(entries.check_new(data, "pages", {
            name = "Room",
            width = 4,
            pixel_per_meter = 10,
            image = "world/q.png"
        }, store), "No asset \"world/q.png\"")
        test.assert_eq(entries.check_new(data, "pages", {
            name = "Room",
            width = 4,
            pixel_per_meter = 10,
            image = "world/n.png",
            tokens = {
                "T"
            }
        }, store), "Cannot set \"tokens\" of a new page")
        test.assert_eq(entries.check_new(data, "groups", {
            title = "Guests"
        }), nil, "the grants default to none")
        test.assert_eq(entries.check_new(data, "token_properties", {
            title = "Speed"
        }), "A new token property needs \"type\"")
        test.assert_eq(entries.check_new(data, "token_properties", {
            title = "Speed",
            type = "number"
        }), nil)
        ---@diagnostic disable-next-line: param-type-mismatch
        test.assert_eq(entries.check_new(data, "groups", "Guests"), "A new group needs \"title\"")
        test.assert_eq(entries.check_new(data, "players", {
            group = "player"
        }), "Players cannot be created")
    end)
end)

test.case("check_delete refuses the kinds never deleted, an unknown id, and an entry the game still uses", function()
    local data = game_data()
    test.assert_eq(entries.check_delete(data, "pages", "Q"), nil)
    test.assert_eq(entries.check_delete(data, "groups", "empty"), nil)
    test.assert_eq(entries.check_delete(data, "token_properties", "notes"), nil)
    test.assert_eq(entries.check_delete(data, "players", "piotr"), "Players cannot be deleted")
    test.assert_eq(entries.check_delete(data, "game", entries.GAME_ID), "The game cannot be deleted")
    test.assert_eq(entries.check_delete(data, "pages", "R"), "No page with the id \"R\"")
    test.assert_eq(entries.check_delete(data, "pages", "P"), "The page \"P\" is shown to the players")
    data.game.page = "Q"
    test.assert_eq(entries.check_delete(data, "pages", "P"), "The page \"P\" still holds tokens")
    test.assert_eq(entries.check_delete(data, "groups", "player"), "A player is in the group \"player\"")
    test.assert_eq(entries.check_delete(data, "token_properties", "avatar"), "\"avatar\" is a property every token has")
    test.assert_eq(entries.check_delete(data, "token_properties", "hp"), "A token holds the property \"hp\"")
end)

test.case("check_rename refuses the kinds never renamed and the properties every token has, then checks the new id", function()
    local data = game_data()
    test.assert_eq(entries.check_rename(data, "pages", "Q", "R"), nil)
    test.assert_eq(entries.check_rename(data, "players", "piotr", "peter"), "Players cannot be renamed")
    test.assert_eq(entries.check_rename(data, "game", entries.GAME_ID, "x"), "The game cannot be renamed")
    test.assert_eq(entries.check_rename(data, "token_properties", "name", "label"), "\"name\" is a property every token has: it keeps its key")
    test.assert_eq(entries.check_rename(data, "pages", "Q", "P"), "A page with the id \"P\" already exists")
    test.assert_eq(entries.check_rename(data, "groups", "empty", "@x"), "An id must not start with \"@\"")
end)

test.case("renaming a page renames its key, the shown page and the grants on it, the other kinds' grants as they were", function()
    local data = game_data()
    local page = data.pages.P
    entries.rename(data, "pages", "P", "Plains")
    test.assert_eq(data.pages.P, nil)
    test.assert_eq(data.pages.Plains, page)
    test.assert_eq(data.game.page, "Plains")
    test.assert_deep_eq(data.groups.player.permissions, {
        "read:pages/Plains",
        "write:groups/player",
        "read:token_properties/hp"
    })
    test.assert_deep_eq(data.players.piotr.permissions, {
        "write:pages/Plains",
        "write:token_properties/hp"
    })
    test.assert_deep_eq(data.players.adam, {
        group = "master"
    }, "a player without grants of its own gets none")
    entries.rename(data, "pages", "Q", "Quarry")
    test.assert_eq(data.game.page, "Plains", "another page renamed leaves the shown one")
end)

test.case("renaming a group moves its players and its grants; renaming a token property moves the key in every token", function()
    local data = game_data()
    entries.rename(data, "groups", "player", "players")
    test.assert_eq(data.groups.player, nil)
    test.assert_eq(data.groups.players.title, "Player")
    test.assert_eq(data.players.piotr.group, "players")
    test.assert_eq(data.players.adam.group, "master")
    test.assert_deep_eq(data.groups.players.permissions, {
        "read:pages/P",
        "write:groups/players",
        "read:token_properties/hp"
    })
    entries.rename(data, "token_properties", "hp", "health")
    test.assert_eq(data.token_properties.hp, nil)
    test.assert_deep_eq(data.token_properties.health, {
        title = "HP",
        type = "number"
    })
    test.assert_eq(data.tokens.T.hp, nil)
    test.assert_eq(data.tokens.T.health, 3)
    test.assert_deep_eq(data.players.piotr.permissions, {
        "write:pages/P",
        "write:token_properties/health"
    })
    test.assert_error(function()
        entries.rename(data, "pages", "P", "Q")
    end, "a rename check_rename refuses")
    test.assert_error(function()
        entries.rename(data, "pages", "R", "S")
    end, "an id the data does not hold")
end)

test.case("remove takes the key and the grants on it, the other grants stay", function()
    local data = game_data()
    entries.remove(data, "token_properties", "hp")
    test.assert_eq(data.token_properties.hp, nil)
    test.assert_eq(data.tokens.T.hp, 3, "removing is for what check_delete accepts: the tokens are not touched")
    test.assert_deep_eq(data.groups.player.permissions, {
        "read:pages/P",
        "write:groups/player"
    })
    test.assert_deep_eq(data.players.piotr.permissions, {
        "write:pages/P"
    })
    entries.remove(data, "groups", "empty")
    test.assert_eq(data.groups.empty, nil)
    test.assert_error(function()
        entries.remove(data, "groups", "empty")
    end)
end)

test.case("apply sets the fields, an array copied; the game entry is applied in place", function()
    local data = game_data()
    local grants = {
        "read"
    }
    entries.apply(data, "groups", "empty", {
        title = "Guests",
        permissions = grants
    })
    test.assert_deep_eq(data.groups.empty, {
        title = "Guests",
        permissions = {
            "read"
        }
    })
    table.insert(grants, "write")
    test.assert_deep_eq(data.groups.empty.permissions, {
        "read"
    }, "a copy")
    entries.apply(data, "game", entries.GAME_ID, {
        page = "Q"
    })
    test.assert_eq(data.game.page, "Q")
end)

test.case("create stores a fresh entry of the kind's fields, a page with no tokens, a group with no grants unless given", function()
    local data = game_data()
    ---@type PageData
    local page = {
        name = "Room",
        width = 4,
        pixel_per_meter = 10,
        image = "world/n.png",
        tokens = {
            "T"
        }
    }
    local created = entries.create(data, "pages", "R", page)
    test.assert_eq(data.pages.R, created)
    test.assert_true(created ~= page, "fresh, the tokens never taken from the request")
    test.assert_deep_eq(created, {
        name = "Room",
        width = 4,
        pixel_per_meter = 10,
        image = "world/n.png",
        tokens = {}
    })
    local grants = {
        "read"
    }
    entries.create(data, "groups", "guests", {
        title = "Guests",
        permissions = grants
    })
    table.insert(grants, "write")
    test.assert_deep_eq(data.groups.guests, {
        title = "Guests",
        permissions = {
            "read"
        }
    })
    ---@type EntryValues
    local group = {
        title = "Others"
    }
    test.assert_deep_eq(entries.create(data, "groups", "others", group), {
        title = "Others",
        permissions = {}
    })
    test.assert_error(function()
        entries.create(data, "players", "ewa", {
            group = "player"
        })
    end)
end)

test.case("is_property_held asks every token", function()
    local data = game_data()
    test.assert_true(entries.is_property_held(data, "hp"))
    test.assert_true(entries.is_property_held(data, "avatar"))
    test.assert_false(entries.is_property_held(data, "notes"))
end)

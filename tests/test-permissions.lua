local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local AssetManager = require("data.asset-manager")
local PermissionSet = require("game.permission-set")
local Session = require("game.session")
local permissions = require("game.permissions")
local Connection = require("networking.connection")
local ScreenManager = require("screens.screen-manager")
local BackstackManager = require("utils.backstack-manager")
local Control = require("controls.control")

local Action = permissions.Action
local Kind = permissions.Kind

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
                    "read"
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
                    "Bilbosz",
                    "Gaben",
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
            Bilbosz = {
                name = "Bilbosz",
                diameter = 3,
                avatar = "token/b.png",
                owners = {
                    "adam"
                },
                position = {
                    1,
                    2
                }
            },
            Gaben = {
                name = "Gaben",
                diameter = 3,
                avatar = "token/g.png",
                owners = {
                    "piotr"
                },
                position = {
                    3,
                    4
                }
            },
            Anonim = {
                name = "Anonim",
                diameter = 2,
                avatar = "token/a.png",
                position = {
                    5,
                    6
                }
            }
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
                    "write:tokens/@owned",
                    "view:tokens/Bilbosz"
                }
            }
        }
    }
end

---@param fn fun()
---@return string
local function error_of(fn)
    ---@type boolean, any
    local ok, err = pcall(fn)
    test.assert_false(ok, "expected an error")
    return tostring(err)
end

test.suite("permissions")

test.case("parse reads every form of a grant", function()
    test.assert_deep_eq(permissions.parse("read"), {
        action = Action.READ
    })
    test.assert_deep_eq(permissions.parse("write:tokens"), {
        action = Action.WRITE,
        kind = Kind.TOKENS
    })
    test.assert_deep_eq(permissions.parse("view:tokens/Bilbosz"), {
        action = Action.VIEW,
        kind = Kind.TOKENS,
        key = "Bilbosz"
    })
    test.assert_deep_eq(permissions.parse("read:pages/Old Town"), {
        action = Action.READ,
        kind = Kind.PAGES,
        key = "Old Town"
    }, "the key keeps its spaces")
    test.assert_deep_eq(permissions.parse("read:pages/a/b"), {
        action = Action.READ,
        kind = Kind.PAGES,
        key = "a/b"
    }, "the key is everything after the first slash")
    test.assert_deep_eq(permissions.parse("write:tokens/@owned"), {
        action = Action.WRITE,
        kind = Kind.TOKENS,
        key = permissions.OWNED
    })
    test.assert_deep_eq(permissions.parse("write:assets"), {
        action = Action.WRITE,
        kind = Kind.ASSETS
    })
end)

test.case("format is the inverse of parse", function()
    for _, text in ipairs({
        "read",
        "write:tokens",
        "view:tokens/Bilbosz",
        "read:pages/Old Town",
        "read:pages/a/b",
        "write:tokens/@owned",
        "write:assets"
    }) do
        local grant = permissions.parse(text)
        test.assert_eq(permissions.format(grant), text)
        test.assert_deep_eq(permissions.parse(permissions.format(grant)), grant)
    end
    test.assert_error(function()
        permissions.format({
            action = Action.READ,
            key = "Bilbosz"
        })
    end, "a key without a kind")
end)

test.case("parse raises on a malformed grant, naming it", function()
    for _, text in ipairs({
        "",
        "reed",
        "READ",
        "read ",
        " read",
        ":tokens",
        "read:",
        "read:/Bilbosz",
        "read:tokens/",
        "read:tokens/@all",
        "read:tokens/@"
    }) do
        local err = error_of(function()
            permissions.parse(text)
        end)
        test.assert_true(string.find(err, string.format("%q", text), 1, true) ~= nil, err)
    end
end)

test.case("parse raises on a kind outside permissions.Kind", function()
    for _, text in ipairs({
        "read:token",
        "read:Tokens",
        "read: tokens",
        "read:assets ",
        "write:token/Bilbosz",
        "write:assets:x"
    }) do
        local err = error_of(function()
            permissions.parse(text)
        end)
        test.assert_true(string.find(err, string.format("Malformed grant %q: unknown kind", text), 1, true) ~= nil, err)
    end
end)

test.case("resolve lists the group's grants, then the player's own", function()
    local data = game_data()
    test.assert_deep_eq(permissions.resolve(data, "adam"), {
        "read",
        "write"
    })
    test.assert_deep_eq(permissions.resolve(data, "piotr"), {
        "read",
        "write:tokens/@owned",
        "view:tokens/Bilbosz"
    })
end)

test.case("resolve takes nothing from an unknown group and logs it; an unknown login raises", function()
    local app_mock = mocks.install_app()
    local data = game_data()
    data.players.piotr.group = "nobody"
    test.assert_deep_eq(permissions.resolve(data, "piotr"), {
        "write:tokens/@owned",
        "view:tokens/Bilbosz"
    })
    test.assert_eq(#app_mock.logs, 1)
    test.assert_true(string.find(tostring(app_mock.logs[1][1]), "nobody", 1, true) ~= nil)
    local err = error_of(function()
        permissions.resolve(data, "mallory")
    end)
    test.assert_true(string.find(err, "mallory", 1, true) ~= nil, err)
end)

test.suite("PermissionSet")

test.case("echoes its login and its grants, as given", function()
    local grants = {
        "read",
        "write:tokens/@owned"
    }
    local set = PermissionSet("piotr", grants)
    test.assert_eq(set:get_login(), "piotr")
    test.assert_deep_eq(set:get_grants(), grants)
    table.insert(set:get_grants(), "write")
    table.insert(grants, "write")
    test.assert_deep_eq(set:get_grants(), {
        "read",
        "write:tokens/@owned"
    }, "neither the given nor the returned array is the set's own")
    test.assert_error(function()
        PermissionSet("piotr", {
            "read",
            "read:"
        })
    end, "every grant is parsed")
end)

test.case("a grant without a kind allows everything of its action", function()
    local set = PermissionSet("adam", {
        "read"
    })
    test.assert_true(set:allows(Action.READ))
    test.assert_true(set:allows(Action.READ, Kind.TOKENS))
    test.assert_true(set:allows(Action.READ, Kind.TOKENS, "Bilbosz"))
    test.assert_true(set:allows(Action.READ, Kind.ASSETS))
    test.assert_false(set:allows(Action.WRITE))
    test.assert_false(set:allows(Action.WRITE, Kind.TOKENS, "Bilbosz"))
    test.assert_false(set:allows(Action.VIEW, Kind.TOKENS, "Bilbosz"))
end)

test.case("a grant of a kind allows the kind and its entries, nothing else", function()
    local set = PermissionSet("adam", {
        "write:tokens"
    })
    test.assert_false(set:allows(Action.WRITE), "not everything")
    test.assert_true(set:allows(Action.WRITE, Kind.TOKENS))
    test.assert_true(set:allows(Action.WRITE, Kind.TOKENS, "Bilbosz"))
    test.assert_false(set:allows(Action.WRITE, Kind.PAGES))
    test.assert_false(set:allows(Action.WRITE, Kind.PAGES, "Old Town"))
    test.assert_false(set:allows(Action.READ, Kind.TOKENS), "write does not grant read")
    test.assert_true(set:allows(Action.WRITE, "tokens"), "a literal of the enum's value is a kind too")
end)

test.case("a grant of a key allows that entry only", function()
    local set = PermissionSet("piotr", {
        "view:tokens/Bilbosz"
    })
    test.assert_true(set:allows(Action.VIEW, Kind.TOKENS, "Bilbosz"))
    test.assert_false(set:allows(Action.VIEW, Kind.TOKENS, "Gaben"))
    test.assert_false(set:allows(Action.VIEW, Kind.TOKENS), "not the whole kind")
    test.assert_false(set:allows(Action.VIEW))
    test.assert_false(set:allows(Action.VIEW, Kind.PAGES, "Bilbosz"))
    test.assert_false(set:allows(Action.READ, Kind.TOKENS, "Bilbosz"))
    test.assert_error(function()
        set:allows(Action.VIEW, nil, "Bilbosz")
    end, "a key without a kind")
end)

test.case("@owned matches the entries whose owners list the login, in app.data as it is when asked", function()
    local app_mock = mocks.install_app()
    local set = PermissionSet("piotr", {
        "write:tokens/@owned",
        "write:pages/@owned",
        "write:assets/@owned"
    })
    test.assert_false(set:allows(Action.WRITE, Kind.TOKENS, "Gaben"), "no data, nothing owned")
    app_mock.data = game_data()
    test.assert_true(set:allows(Action.WRITE, Kind.TOKENS, "Gaben"))
    test.assert_false(set:allows(Action.WRITE, Kind.TOKENS, "Bilbosz"), "another player's")
    test.assert_false(set:allows(Action.WRITE, Kind.TOKENS, "Anonim"), "no owners")
    test.assert_false(set:allows(Action.WRITE, Kind.TOKENS, "Nobody"), "no such entry")
    test.assert_false(set:allows(Action.WRITE, Kind.PAGES, "Old Town"), "a page has no owners")
    test.assert_false(set:allows(Action.WRITE, Kind.ASSETS, "token/g.png"), "the kind is not in the data")
    test.assert_false(set:allows(Action.WRITE, Kind.TOKENS), "not the whole kind")
    test.assert_false(set:allows(Action.READ, Kind.TOKENS, "Gaben"))
    table.insert(assert(app_mock.data.tokens.Bilbosz.owners), "piotr")
    test.assert_true(set:allows(Action.WRITE, Kind.TOKENS, "Bilbosz"), "evaluated when asked")
end)

test.suite("permissions.filter")

test.case("reading everything keeps every entry, a copy, without the players' auth", function()
    mocks.install_app()
    local data = game_data()
    local result = permissions.filter(data, PermissionSet("adam", {
        "read"
    }))
    local expected = game_data()
    expected.players.adam.auth = nil
    expected.players.piotr.auth = nil
    test.assert_deep_eq(result, expected)
    test.assert_deep_eq(data, game_data(), "the original is untouched")
    result.tokens.Bilbosz.position[1] = 99
    table.insert(result.pages["Old Town"].tokens, "Extra")
    result.game.page = "Elsewhere"
    test.assert_deep_eq(data, game_data(), "nothing of the original is reachable through the copy")
end)

test.case("an entry is kept only when readable, and a kept page lists only kept tokens", function()
    local app_mock = mocks.install_app()
    local data = game_data()
    app_mock.data = data
    local result = permissions.filter(data, PermissionSet("piotr", {
        "read:pages",
        "read:tokens/Bilbosz",
        "read:tokens/@owned",
        "read:players/piotr"
    }))
    test.assert_deep_eq(result.tokens, {
        Bilbosz = game_data().tokens.Bilbosz,
        Gaben = game_data().tokens.Gaben
    })
    test.assert_deep_eq(result.pages["Old Town"].tokens, {
        "Bilbosz",
        "Gaben"
    })
    test.assert_deep_eq(result.players, {
        piotr = {
            name = "Piotrek",
            group = "player",
            permissions = {
                "write:tokens/@owned",
                "view:tokens/Bilbosz"
            }
        }
    })
    test.assert_deep_eq(result.game, {}, "no read on game")
    test.assert_deep_eq(result.groups, {})
    test.assert_deep_eq(result.token_properties, {})
    test.assert_deep_eq(data, game_data(), "the original is untouched")
end)

test.case("reading the game keeps it whole; nothing read gives empty tables, not nil", function()
    mocks.install_app()
    local data = game_data()
    local game_only = permissions.filter(data, PermissionSet("piotr", {
        "read:game"
    }))
    test.assert_deep_eq(game_only, {
        game = {
            page = "Old Town"
        },
        groups = {},
        pages = {},
        players = {},
        token_properties = {},
        tokens = {}
    })
    test.assert_deep_eq(permissions.filter(data, PermissionSet("piotr", {
        "write",
        "view"
    })), {
        game = {},
        groups = {},
        pages = {},
        players = {},
        token_properties = {},
        tokens = {}
    }, "write and view do not read")
end)

test.suite("Session permissions")

---@param overrides {is_client: boolean, is_server: boolean}|nil
---@return AppMock
---@return Connection
local function make_app(overrides)
    local app_mock = mocks.install_app(overrides)
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500
    app_mock.screen_manager = ScreenManager()
    app_mock.backstack_manager = BackstackManager()
    app_mock.data = game_data()
    local connection = Connection(mocks.make_channel(), mocks.make_channel())
    return app_mock, connection
end

---@param session Session
---@param user string
local function log_in(session, user)
    ---@diagnostic disable-next-line: invisible
    session._login._login_rp.on_login(user)
end

---@param session Session
local function log_out(session)
    ---@diagnostic disable-next-line: invisible
    session._login._logout_rp.on_logout()
end

test.case("the server's session resolves its set at login and clears it at logout", function()
    local previous = mocks.install_love_filesystem({
        ["server/assets/token/g.png"] = "G"
    })
    local app_mock, connection = make_app({
        is_client = false,
        is_server = true
    })
    app_mock.asset_manager = AssetManager()
    local session = Session(connection):attach_lifetime(connection)
    test.assert_error(function()
        session:get_permissions()
    end, "not before the login")
    test.assert_error(function()
        session:set_grants({
            "read"
        })
    end, "the server resolves its own")
    log_in(session, "piotr")
    local set = session:get_permissions()
    test.assert_eq(set:get_login(), "piotr")
    test.assert_deep_eq(set:get_grants(), permissions.resolve(assert(app_mock.data), "piotr"))
    test.assert_true(set:allows(Action.WRITE, Kind.TOKENS, "Gaben"))
    log_out(session)
    test.assert_error(function()
        session:get_permissions()
    end, "not after the logout")
    lifetime.destroy(connection)
    mocks.restore_love_filesystem(previous)
end)

test.case("the client's session takes its grants after the login and drops them at logout", function()
    local app_mock, connection = make_app()
    app_mock.asset_manager = AssetManager()
    local session = Session(connection):attach_lifetime(connection)
    test.assert_error(function()
        session:get_permissions()
    end, "not before the login")
    test.assert_error(function()
        session:set_grants({
            "read"
        })
    end, "no user yet")
    log_in(session, "piotr")
    test.assert_error(function()
        session:get_permissions()
    end, "not before the game data")
    session:set_grants({
        "read",
        "write:tokens/@owned"
    })
    local set = session:get_permissions()
    test.assert_eq(set:get_login(), "piotr")
    test.assert_deep_eq(set:get_grants(), {
        "read",
        "write:tokens/@owned"
    })
    log_out(session)
    test.assert_error(function()
        session:get_permissions()
    end, "not after the logout")
    lifetime.destroy(connection)
end)

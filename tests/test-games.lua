local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Game = require("game.game")
local Games = require("data.games")
local lifetime = require("lifetime")

---@param name string
---@return string
local function save_of(name)
    return table.to_string({
        name = name,
        game = {
            page = "P"
        },
        pages = {},
        token_properties = {},
        tokens = {},
        players = {
            adam = {
                group = "master"
            }
        },
        groups = {}
    })
end

---@return string
local function template()
    return table.to_string({
        name = "",
        game = {
            page = "Table"
        },
        pages = {},
        token_properties = {},
        tokens = {
            Hero = {
                name = "Hero",
                diameter = 1,
                avatar = "token/default.png",
                owners = {},
                position = {
                    10,
                    7.5
                }
            },
            Rock = {
                name = "Rock",
                diameter = 1,
                avatar = "token/default.png",
                position = {
                    1,
                    1
                }
            }
        },
        players = {},
        groups = {}
    })
end

---@param files table<string, string>
---@param fn fun(games: Games)
local function with_games(files, fn)
    mocks.install_app({
        is_client = false,
        is_server = true
    })
    local previous = mocks.install_love_filesystem(files)
    ---@type boolean, any
    local ok, err = pcall(fn, Games("s/games"))
    mocks.restore_love_filesystem(previous)
    if not ok then
        error(err, 0)
    end
end

---@param path string
---@return GameData
local function read_save(path)
    return table.from_string(assert(love.filesystem.read(path))) --[[@as GameData]]
end

test.suite("Games")

test.case("an id is the name in lower case, every run of other characters one dash, none at the ends", function()
    test.assert_eq(Games.make_id("Meadow"), "meadow")
    test.assert_eq(Games.make_id("The Shire"), "the-shire")
    test.assert_eq(Games.make_id("  The   Shire!! 2 "), "the-shire-2")
    test.assert_eq(Games.make_id("--Old_Town--"), "old-town")
    test.assert_eq(Games.make_id("Kraków"), "krak-w")
    test.assert_eq(Games.make_id("42"), "42")
    test.assert_eq(Games.make_id(""), nil)
    test.assert_eq(Games.make_id(" !?- "), nil)
end)

test.case("the games are the directories with a save, by id; a game is loaded once and kept", function()
    with_games({
        ["s/games/meadow/save.lua"] = save_of("Meadow"),
        ["s/games/old-town/save.lua"] = save_of("Old Town"),
        ["s/games/old-town/assets/world/w.png"] = "W",
        ["s/games/empty/assets/x.png"] = "X",
        ["s/games/Bad Name/save.lua"] = save_of("Bad")
    }, function(games)
        test.assert_deep_eq(games:list(), {
            "meadow",
            "old-town"
        })
        local game = assert(games:get("old-town"))
        test.assert_eq(game:get_id(), "old-town")
        test.assert_eq(game:get_name(), "Old Town")
        test.assert_eq(game:get_store():get_root(), "s/games/old-town")
        test.assert_eq(game:get_store():asset("world/w.png"):read(), "W")
        test.assert_eq(games:get("old-town"), game, "the same game")
        test.assert_eq(games:get("empty"), nil, "no save, no game")
        test.assert_eq(games:get("none"), nil)
        test.assert_eq(games:get("../games/meadow"), nil, "an id is never a path")
        test.assert_eq(games:get("Bad Name"), nil)
    end)
    with_games({}, function(games)
        test.assert_deep_eq(games:list(), {}, "no games directory, no games")
    end)
end)

test.case("a game adds a player once, saved, and saves its data as it is", function()
    local files = {
        ["s/games/meadow/save.lua"] = save_of("Meadow")
    }
    with_games(files, function()
        local game = Game("meadow", "s/games/meadow")
        game:add_player("piotr", "player")
        test.assert_deep_eq(read_save("s/games/meadow/save.lua").players, {
            adam = {
                group = "master"
            },
            piotr = {
                group = "player"
            }
        })
        game:add_player("adam", "player")
        test.assert_deep_eq(game:get_data().players.adam, {
            group = "master"
        }, "a player keeps its group")
        game:get_data().game.page = "Q"
        game:save()
        test.assert_eq(read_save("s/games/meadow/save.lua").game.page, "Q")
    end)
end)

test.case("a new game is the template under its id, named, its creator the master and the owner of every token", function()
    with_games({
        ["server/template/save.lua"] = template(),
        ["server/template/assets/token/default.png"] = "D",
        ["s/games/meadow/save.lua"] = save_of("Meadow")
    }, function(games)
        local game, err = games:create("The Shire", "frodo")
        test.assert_eq(err, nil)
        game = assert(game)
        test.assert_eq(game:get_id(), "the-shire")
        test.assert_eq(games:get("the-shire"), game)
        local saved = read_save("s/games/the-shire/save.lua")
        test.assert_eq(saved.name, "The Shire")
        test.assert_deep_eq(saved.players, {
            frodo = {
                group = "master"
            }
        })
        test.assert_deep_eq(saved.tokens.Hero.owners, {
            "frodo"
        })
        test.assert_deep_eq(saved.tokens.Rock.owners, {
            "frodo"
        })
        test.assert_eq(love.filesystem.read("s/games/the-shire/assets/token/default.png"), "D")
        test.assert_deep_eq(games:list(), {
            "meadow",
            "the-shire"
        })
        test.assert_eq(read_save("server/template/save.lua").name, "", "the template stays")
    end)
end)

test.case("a fresh root has no games; the first game makes the games directory and its own", function()
    local files = {
        ["server/template/save.lua"] = template(),
        ["server/template/assets/token/default.png"] = "D"
    }
    with_games(files, function(games)
        test.assert_eq(love.filesystem.getInfo("s"), nil, "nothing under the root")
        test.assert_deep_eq(games:list(), {})
        test.assert_eq(games:get("bag-end"), nil)
        local game = assert(games:create("Bag End", "frodo"))
        test.assert_eq(game:get_id(), "bag-end")
        test.assert_eq(assert(love.filesystem.getInfo("s/games")).type, "directory")
        test.assert_eq(read_save("s/games/bag-end/save.lua").name, "Bag End")
        test.assert_eq(love.filesystem.read("s/games/bag-end/assets/token/default.png"), "D")
        test.assert_deep_eq(games:list(), {
            "bag-end"
        })
        test.assert_deep_eq(Games("s/games"):list(), {
            "bag-end"
        }, "listed by a server started again")
    end)
end)

test.case("a deleted game is gone with its directory, no longer listed, and its id is free for a new game", function()
    with_games({
        ["server/template/save.lua"] = template(),
        ["s/games/meadow/save.lua"] = save_of("Meadow"),
        ["s/games/meadow/assets/world/w.png"] = "W",
        ["s/games/old-town/save.lua"] = save_of("Old Town")
    }, function(games)
        local game = assert(games:get("meadow"))
        games:delete("meadow")
        test.assert_eq(games:get("meadow"), nil)
        test.assert_eq(love.filesystem.getInfo("s/games/meadow"), nil)
        test.assert_deep_eq(games:list(), {
            "old-town"
        })
        test.assert_eq(game:get_name(), "Meadow", "the object a holder keeps is unchanged")
        local again = assert(games:create("Meadow", "frodo"))
        test.assert_true(again ~= game, "a new game under the id")
        test.assert_eq(love.filesystem.getInfo("s/games/meadow/assets/world/w.png"), nil, "nothing of the old one")
        test.assert_error(function()
            games:delete("none")
        end)
    end)
end)

test.case("a game answers whether a login's grants in it allow an action: a player's, resolved from the data; nothing for anyone else", function()
    local side = mocks.make_server_session(mocks.entries_game_data, {})
    ---@type boolean, any
    local ok, err = pcall(function()
        local game = assert(assert(side.server.games):get(mocks.GAME_ID))
        test.assert_true(game:allows("adam", "write", "game"))
        test.assert_true(game:allows("adam", "read"))
        test.assert_false(game:allows("piotr", "write", "game"))
        test.assert_true(game:allows("piotr", "read", "groups"))
        test.assert_false(game:allows("nobody", "read"))
        game:get_data().players.piotr.permissions = {
            "write:game"
        }
        test.assert_true(game:allows("piotr", "write", "game"), "read from the data at the moment of the question")
    end)
    mocks.finish_server_session(side)
    if not ok then
        error(err, 0)
    end
end)

test.case("a new game is refused without a letter or a digit, with a name too long, or where a game is", function()
    with_games({
        ["server/template/save.lua"] = template(),
        ["s/games/meadow/save.lua"] = save_of("Meadow")
    }, function(games)
        test.assert_deep_eq({
            games:create(" !! ", "frodo")
        }, {
            nil,
            "A game needs a name with a letter or a digit"
        })
        test.assert_deep_eq({
            games:create(string.rep("a", 65), "frodo")
        }, {
            nil,
            "A game's name can have at most 64 characters"
        })
        test.assert_deep_eq({
            games:create("MEADOW!", "frodo")
        }, {
            nil,
            "A game named \"Meadow\" exists already"
        })
        test.assert_deep_eq(games:list(), {
            "meadow"
        })
        test.assert_eq(read_save("s/games/meadow/save.lua").name, "Meadow", "untouched")
    end)
end)

test.case("refreshing a game's permissions rebuilds every live session's set from the data and gives the sessions whose grants changed", function()
    local side = mocks.make_server_session(mocks.entries_game_data, {})
    ---@type boolean, any
    local ok, err = pcall(function()
        test.assert_false(side.session:refresh_permissions(), "no game, nothing to refresh")
        mocks.join_game(side.connection, "adam")
        local piotr_connection, piotr = mocks.join_another("piotr")
        local ewa_connection = mocks.join_another("ewa")
        local game = side.session:get_game()
        test.assert_deep_eq(game:refresh_permissions(), {}, "the data as it was")
        local data = game:get_data()
        data.groups.player.permissions = {
            "read",
            "write:tokens"
        }
        test.assert_deep_eq(game:refresh_permissions(), {
            piotr
        })
        test.assert_deep_eq(piotr:get_permissions():get_grants(), {
            "read",
            "write:tokens",
            "write:pages/P"
        })
        test.assert_deep_eq(game:refresh_permissions(), {}, "rebuilt already")
        data.players.piotr.permissions = {
            "write:tokens",
            "read"
        }
        test.assert_deep_eq(game:refresh_permissions(), {
            piotr
        }, "the order of the grants counts")
        lifetime.destroy(ewa_connection)
        data.groups.watcher.permissions = {}
        test.assert_deep_eq(game:refresh_permissions(), {}, "a dead session is no longer in the game")
        lifetime.destroy(piotr_connection)
    end)
    mocks.finish_server_session(side)
    if not ok then
        error(err, 0)
    end
end)

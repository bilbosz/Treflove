local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Asset = require("data.asset")

---@param files table<string, string>
---@param fn fun()
local function with_server_store(files, fn)
    mocks.install_app({
        is_client = false,
        is_server = true
    })
    local previous = mocks.install_love_filesystem(files)
    ---@type boolean, any
    local ok, err = pcall(fn)
    mocks.restore_love_filesystem(previous)
    if not ok then
        error(err, 0)
    end
end

test.suite("Asset")

test.case("a path is checked: absolute, empty, trailing slash, empty names, . and .. are refused", function()
    test.assert_eq(Asset.check_path("token/b.png"), nil)
    test.assert_eq(Asset.check_path("b.png"), nil)
    test.assert_eq(Asset.check_path(""), "an empty path")
    test.assert_eq(Asset.check_path("/token"), "an absolute path")
    test.assert_eq(Asset.check_path("token/"), "a path ending with /")
    test.assert_eq(Asset.check_path("token//b.png"), "an empty name")
    test.assert_eq(Asset.check_path("token/./b.png"), "the name \".\"")
    test.assert_eq(Asset.check_path("../save.lua"), "the name \"..\"")
end)

test.case("a path is split into its name and its parent, joined and tested for an ancestor", function()
    test.assert_eq(Asset.get_name("token/b.png"), "b.png")
    test.assert_eq(Asset.get_name("b.png"), "b.png")
    test.assert_eq(Asset.get_parent("token/sub/b.png"), "token/sub")
    test.assert_eq(Asset.get_parent("b.png"), "")
    test.assert_eq(Asset.join("", "b.png"), "b.png")
    test.assert_eq(Asset.join("token", "b.png"), "token/b.png")
    test.assert_true(Asset.is_under("token/b.png", "token"))
    test.assert_true(Asset.is_under("token", "token"))
    test.assert_false(Asset.is_under("tokens/b.png", "token"), "a sibling with the prefix is not under it")
    test.assert_false(Asset.is_under("token", "token/b.png"))
end)

test.case("the store is listed parents first, siblings by name, with the files' sizes", function()
    with_server_store({
        ["s/assets/world/w.png"] = "WW",
        ["s/assets/token/t.png"] = "T",
        ["s/assets/token/a.png"] = "A",
        ["s/assets/notes.txt"] = "hello"
    }, function()
        test.assert_deep_eq(Asset.list(), {
            {
                path = "notes.txt",
                type = "file",
                size = 5
            },
            {
                path = "token",
                type = "directory"
            },
            {
                path = "token/a.png",
                type = "file",
                size = 1
            },
            {
                path = "token/t.png",
                type = "file",
                size = 1
            },
            {
                path = "world",
                type = "directory"
            },
            {
                path = "world/w.png",
                type = "file",
                size = 2
            }
        })
    end)
end)

test.case("an empty store lists nothing", function()
    with_server_store({}, function()
        test.assert_deep_eq(Asset.list(), {})
    end)
end)

test.case("a directory is created with its parents and listed while empty", function()
    with_server_store({}, function()
        Asset("maps/old", false):create_directory()
        test.assert_eq(Asset("maps", false):get_type(), "directory")
        test.assert_eq(Asset("maps/old", false):get_type(), "directory")
        test.assert_deep_eq(Asset.list(), {
            {
                path = "maps",
                type = "directory"
            },
            {
                path = "maps/old",
                type = "directory"
            }
        })
    end)
end)

test.case("a file is moved, and a directory with everything under it", function()
    with_server_store({
        ["s/assets/token/t.png"] = "T",
        ["s/assets/token/sub/a.png"] = "A"
    }, function()
        Asset("token/t.png", false):move_to(Asset("token/u.png", false))
        test.assert_eq(Asset("token/t.png", false):get_type(), nil)
        test.assert_eq(Asset("token/u.png", false):read(), "T")

        Asset("token", false):move_to(Asset("people/all", false))
        test.assert_eq(Asset("token", false):get_type(), nil)
        test.assert_eq(Asset("people/all/u.png", false):read(), "T")
        test.assert_eq(Asset("people/all/sub/a.png", false):read(), "A")
        test.assert_eq(Asset("people", false):get_type(), "directory", "the destination's parent was made")
    end)
end)

test.case("a move needs a source and a free destination", function()
    with_server_store({
        ["s/assets/a.png"] = "A",
        ["s/assets/b.png"] = "B"
    }, function()
        test.assert_error(function()
            Asset("c.png", false):move_to(Asset("d.png", false))
        end, "nothing to move")
        test.assert_error(function()
            Asset("a.png", false):move_to(Asset("b.png", false))
        end, "the destination exists")
        test.assert_eq(Asset("a.png", false):read(), "A")
        test.assert_eq(Asset("b.png", false):read(), "B")
    end)
end)

test.case("a file is removed, and a directory with everything under it; removing what is not there does nothing", function()
    with_server_store({
        ["s/assets/token/t.png"] = "T",
        ["s/assets/token/sub/a.png"] = "A",
        ["s/assets/world/w.png"] = "W"
    }, function()
        Asset("world/w.png", false):remove()
        test.assert_eq(Asset("world/w.png", false):get_type(), nil)
        Asset("token", false):remove()
        test.assert_eq(Asset("token", false):get_type(), nil)
        test.assert_eq(Asset("token/sub/a.png", false):get_type(), nil)
        Asset("token", false):remove()
        test.assert_deep_eq(Asset.list(), {
            {
                path = "world",
                type = "directory"
            }
        }, "a folder stays when its last file goes")
        Asset("world", false):remove()
        test.assert_deep_eq(Asset.list(), {})
    end)
end)

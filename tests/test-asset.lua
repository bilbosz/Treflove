local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Asset = require("data.asset")

---@param files table<string, string>
---@param fn fun()
local function with_files(files, fn)
    mocks.install_app()
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

test.case("a file is moved, and a directory with everything under it", function()
    with_files({
        ["r/token/t.png"] = "T",
        ["r/token/sub/a.png"] = "A"
    }, function()
        Asset("r/token/t.png"):move_to(Asset("r/token/u.png"))
        test.assert_eq(Asset("r/token/t.png"):get_type(), nil)
        test.assert_eq(Asset("r/token/u.png"):read(), "T")

        Asset("r/token"):move_to(Asset("r/people/all"))
        test.assert_eq(Asset("r/token"):get_type(), nil)
        test.assert_eq(Asset("r/people/all/u.png"):read(), "T")
        test.assert_eq(Asset("r/people/all/sub/a.png"):read(), "A")
        test.assert_eq(Asset("r/people"):get_type(), "directory", "the destination's parent was made")
    end)
end)

test.case("a move needs a source and a free destination", function()
    with_files({
        ["r/a.png"] = "A",
        ["r/b.png"] = "B"
    }, function()
        test.assert_error(function()
            Asset("r/c.png"):move_to(Asset("r/d.png"))
        end, "nothing to move")
        test.assert_error(function()
            Asset("r/a.png"):move_to(Asset("r/b.png"))
        end, "the destination exists")
        test.assert_eq(Asset("r/a.png"):read(), "A")
        test.assert_eq(Asset("r/b.png"):read(), "B")
    end)
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local AssetStore = require("data.asset-store")

---@param files table<string, string>
---@param fn fun(store: AssetStore) Over the store `s/games/g`
local function with_store(files, fn)
    mocks.install_app({
        is_client = false,
        is_server = true
    })
    mocks.ensure_love_data()
    local previous = mocks.install_love_filesystem(files)
    ---@type boolean, any
    local ok, err = pcall(fn, AssetStore("s/games/g"))
    mocks.restore_love_filesystem(previous)
    if not ok then
        error(err, 0)
    end
end

---@param text string
---@return string
local function base64(text)
    return love.data.encode("string", "base64", text) --[[@as string]]
end

test.suite("AssetStore")

test.case("the store is listed parents first, siblings by name, with the files' sizes", function()
    with_store({
        ["s/games/g/assets/world/w.png"] = "WW",
        ["s/games/g/assets/token/t.png"] = "T",
        ["s/games/g/assets/token/a.png"] = "A",
        ["s/games/g/assets/notes.txt"] = "hello"
    }, function(store)
        test.assert_deep_eq(store:list(), {
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
    with_store({}, function(store)
        test.assert_deep_eq(store:list(), {})
    end)
end)

test.case("a directory is created with its parents and listed while empty", function()
    with_store({}, function(store)
        store:asset("maps/old"):create_directory()
        test.assert_eq(store:asset("maps"):get_type(), "directory")
        test.assert_eq(store:asset("maps/old"):get_type(), "directory")
        test.assert_deep_eq(store:list(), {
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

test.case("a file is removed, and a directory with everything under it; removing what is not there does nothing", function()
    with_store({
        ["s/games/g/assets/token/t.png"] = "T",
        ["s/games/g/assets/token/sub/a.png"] = "A",
        ["s/games/g/assets/world/w.png"] = "W"
    }, function(store)
        store:asset("world/w.png"):remove()
        test.assert_eq(store:asset("world/w.png"):get_type(), nil)
        store:asset("token"):remove()
        test.assert_eq(store:asset("token"):get_type(), nil)
        test.assert_eq(store:asset("token/sub/a.png"):get_type(), nil)
        store:asset("token"):remove()
        test.assert_deep_eq(store:list(), {
            {
                path = "world",
                type = "directory"
            }
        }, "a folder stays when its last file goes")
        store:asset("world"):remove()
        test.assert_deep_eq(store:list(), {})
    end)
end)

test.case("a store is bound to its root: an asset's path is under the root's assets, whether it exists or not", function()
    with_store({
        ["s/games/g/assets/token/t.png"] = "T"
    }, function(store)
        test.assert_eq(store:get_root(), "s/games/g")
        test.assert_eq(store:get_path("token/t.png"), "s/games/g/assets/token/t.png")
        test.assert_eq(store:asset("token/t.png"):get_path(), "s/games/g/assets/token/t.png")
        test.assert_eq(store:asset("token/none.png"):get_path(), nil)
        test.assert_eq(AssetStore("s/games/h"):asset("token/t.png"):get_type(), nil, "another root holds other assets")
    end)
end)

test.case("a file is mounted from base64, made with its folders or written over; a folder or a bad path is refused", function()
    with_store({
        ["s/games/g/assets/token/t.png"] = "T"
    }, function(store)
        test.assert_deep_eq({
            store:mount_file("maps/new/m.png", base64("M"))
        }, {
            true
        })
        test.assert_eq(store:asset("maps/new/m.png"):read(), "M")
        test.assert_true((store:mount_file("token/t.png", base64("U"))))
        test.assert_eq(store:asset("token/t.png"):read(), "U")
        test.assert_deep_eq({
            store:mount_file("token", base64("X"))
        }, {
            false,
            "Cannot upload \"token\": it is a folder"
        })
        test.assert_deep_eq({
            store:mount_file("../accounts.lua", base64("X"))
        }, {
            false,
            "Cannot upload \"../accounts.lua\": the name \"..\""
        })
    end)
end)

test.case("a file's content is base64; a folder, a missing file and a bad path have none", function()
    with_store({
        ["s/games/g/assets/token/t.png"] = "T",
        ["s/games/g/save.lua"] = "return {}"
    }, function(store)
        test.assert_eq(love.data.decode("string", "base64", assert(store:get_content("token/t.png"))), "T")
        test.assert_eq(store:get_content("token"), nil)
        test.assert_eq(store:get_content("token/none.png"), nil)
        test.assert_eq(store:get_content("../save.lua"), nil)
    end)
end)

test.case("a folder is made where nothing is; a move and a removal are refused with the reason", function()
    with_store({
        ["s/games/g/assets/token/t.png"] = "T",
        ["s/games/g/assets/world/w.png"] = "W"
    }, function(store)
        test.assert_true((store:make_folder("maps")))
        test.assert_eq(store:asset("maps"):get_type(), "directory")
        test.assert_deep_eq({
            store:make_folder("token/t.png")
        }, {
            false,
            "Cannot create \"token/t.png\": it exists already"
        })
        test.assert_deep_eq({
            store:move("token", "token/inner")
        }, {
            false,
            "Cannot rename \"token\" to \"token/inner\": it would end up under itself"
        })
        test.assert_deep_eq({
            store:move("token/t.png", "world/w.png")
        }, {
            false,
            "Cannot rename \"token/t.png\" to \"world/w.png\": it exists already"
        })
        test.assert_deep_eq({
            store:move("token/none.png", "x.png")
        }, {
            false,
            "Cannot rename \"token/none.png\": there is no such asset"
        })
        test.assert_true((store:move("token", "people/token")))
        test.assert_eq(store:asset("people/token/t.png"):read(), "T")
        test.assert_deep_eq({
            store:remove("token")
        }, {
            false,
            "Cannot delete \"token\": there is no such asset"
        })
        test.assert_deep_eq({
            store:remove("")
        }, {
            false,
            "Cannot delete \"\": an empty path"
        })
        test.assert_true((store:remove("people")))
        test.assert_eq(store:asset("people/token/t.png"):get_type(), nil)
    end)
end)

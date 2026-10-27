local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local fixture = require("data.fixture")

---@class TestFixtureWorld
---@field files table<string, string> The in-memory file system
---@field removed string[] Every path removed, in order
---@field previous_filesystem love.filesystem|nil

---@param files table<string, string>
---@return TestFixtureWorld
local function setup(files)
    local previous = mocks.install_love_filesystem(files)
    ---@type TestFixtureWorld
    local world = {
        files = files,
        removed = {},
        previous_filesystem = previous
    }
    local fake = assert(love.filesystem)
    ---@class TestFixtureFilesystem: love.filesystem
    local recording = setmetatable({}, {
        __index = fake
    })
    ---@param path string
    ---@return boolean
    function recording.remove(path)
        table.insert(world.removed, path)
        return fake.remove(path)
    end
    love.filesystem = recording
    return world
end

---@param world TestFixtureWorld
local function finish(world)
    mocks.restore_love_filesystem(world.previous_filesystem)
end

---@param world TestFixtureWorld
---@param prefix string
---@return table<string, string> The files under `prefix`, by their path below it
local function files_under(world, prefix)
    ---@type table<string, string>
    local found = {}
    for path, content in pairs(world.files) do
        if path:sub(1, #prefix + 1) == prefix .. "/" then
            found[path:sub(#prefix + 2)] = content
        end
    end
    return found
end

test.suite("fixture")

test.case("seeding empties the root, files first, then the directories deepest first, and copies the source", function()
    local world = setup({
        ["src/save.lua"] = "return {}",
        ["src/assets/world/w.png"] = "W",
        ["src/assets/token/t.png"] = "T",
        ["s/save.lua"] = "old",
        ["s/assets/deep/er/x.png"] = "X"
    })
    love.filesystem.createDirectory("s/empty")
    fixture.seed("src", "s")
    test.assert_deep_eq(world.removed, {
        "s/assets/deep/er/x.png",
        "s/save.lua",
        "s/empty",
        "s/assets/deep/er",
        "s/assets/deep",
        "s/assets"
    })
    test.assert_deep_eq(files_under(world, "s"), {
        ["save.lua"] = "return {}",
        ["assets/world/w.png"] = "W",
        ["assets/token/t.png"] = "T"
    })
    test.assert_eq(love.filesystem.getInfo("s/empty"), nil)
    test.assert_deep_eq(files_under(world, "src"), files_under(world, "s"), "the source stays")
    finish(world)
end)

test.case("an empty directory of the source is copied too, into a root that did not exist", function()
    local world = setup({
        ["src/save.lua"] = ""
    })
    love.filesystem.createDirectory("src/assets")
    fixture.seed("src", "s")
    test.assert_deep_eq(world.removed, {})
    test.assert_deep_eq(files_under(world, "s"), {
        ["save.lua"] = ""
    })
    test.assert_eq(assert(love.filesystem.getInfo("s/assets")).type, "directory")
    finish(world)
end)

test.case("a missing source raises before anything is removed", function()
    local world = setup({
        ["s/save.lua"] = "old"
    })
    test.assert_error(function()
        fixture.seed("nowhere", "s")
    end)
    test.assert_deep_eq(world.removed, {})
    test.assert_eq(world.files["s/save.lua"], "old")
    finish(world)
end)

test.case("a root under directories that do not exist yet is made with them, as a new game's", function()
    local world = setup({
        ["template/save.lua"] = "return {}",
        ["template/assets/world/table.png"] = "TABLE",
        ["s/accounts.lua"] = "return {}"
    })
    fixture.seed("template", "s/games/new")
    test.assert_deep_eq(files_under(world, "s/games/new"), {
        ["save.lua"] = "return {}",
        ["assets/world/table.png"] = "TABLE"
    })
    test.assert_eq(world.files["s/accounts.lua"], "return {}", "what is beside the root stays")
    finish(world)
end)

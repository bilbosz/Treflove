local test = require("tests.lib.test")
local lifetime = require("lifetime")

-- The class system and the lifetime runtime (docs/lifetime.md): `release` is
-- the destructor, every instance of a class with a `release` is registered,
-- and `lifetime.attach(x, false, owner)` is what `x @ owner` compiles to.

---@type string[]
local log = {}

---@class TestOwned: Object
---@field name string
local TestOwned = class("TestOwned")

---@param name string
function TestOwned:init(name)
    self.name = name
end

---@param reason string
function TestOwned:release(reason)
    table.insert(log, self.name .. " " .. tostring(reason))
end

---@class TestPlain: Object
local TestPlain = class("TestPlain")

local function _reset()
    for i = #log, 1, -1 do
        log[i] = nil
    end
end

-- Created in a function of its own, so that no register of the caller
-- keeps the dependent alive.
---@param owner TestOwned
local function _drop_dependent(owner)
    lifetime.attach(TestOwned("dropped"), false, owner)
end

local function _drop_instance()
    TestOwned("solo")
end

test.suite("class + lifetime")

test.case("destroy runs the owner's release first, then its dependents newest first", function()
    _reset()
    local owner = TestOwned("owner")
    local first = lifetime.attach(TestOwned("first"), false, owner)
    local second = lifetime.attach(TestOwned("second"), false, owner)
    test.assert_deep_eq(log, {}, "nothing dies before the destroy")

    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "owner destroy",
        "second anchor",
        "first anchor"
    })
    test.assert_false(lifetime.alive(owner))
    test.assert_false(lifetime.alive(first))
    test.assert_false(lifetime.alive(second))
end)

test.case("a dead object is a tombstone that raises on index", function()
    _reset()
    local owner = TestOwned("tomb")
    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "tomb destroy"
    })
    test.assert_false(lifetime.alive(owner))
    local ok, err = pcall(function()
        return owner.name
    end)
    test.assert_false(ok)
    test.assert_true(string.find(tostring(err), "attempt to index a dead table", 1, true) ~= nil, tostring(err))
    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "tomb destroy"
    }, "destroying a dead object is a no-op")
end)

test.case("a dependent dropped on the floor dies unreachable at the next collection", function()
    _reset()
    local owner = TestOwned("keeper")
    _drop_dependent(owner)
    test.assert_deep_eq(log, {}, "alive until the collector finds it")
    collectgarbage("collect")
    collectgarbage("collect")
    test.assert_deep_eq(log, {
        "dropped unreachable"
    })
    test.assert_true(lifetime.alive(owner), "the owner is not affected")
    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "dropped unreachable",
        "keeper destroy"
    })
end)

test.case("an instance with a release is registered: collected, it runs its release", function()
    _reset()
    _drop_instance()
    collectgarbage("collect")
    collectgarbage("collect")
    test.assert_deep_eq(log, {
        "solo unreachable"
    })
end)

test.case("an instance without a release can be anchored and destroyed", function()
    _reset()
    local owner = TestOwned("plain-owner")
    local plain = lifetime.attach(TestPlain(), false, owner)
    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "plain-owner destroy"
    })
    test.assert_false(lifetime.alive(plain))
end)

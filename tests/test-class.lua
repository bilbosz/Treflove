local test = require("tests.lib.test")
local lifetime = require("lifetime")

-- Base classes must be fully defined before deriving from them: `class()`
-- copies base methods at creation time (see _create_index in utils/class.lua).
local Animal = class("TestAnimal")

---@param name string
function Animal:init(name)
    self.name = name
end

---@return string
function Animal:describe()
    return "animal " .. self.name
end

---@return string
function Animal:noise()
    return "..."
end

local Pet = class("TestPet")

---@return string
function Pet:describe()
    return "pet"
end

---@return string
function Pet:owner()
    return "adam"
end

local Dog = class("TestDog", Animal, Pet)

---@return string
function Dog:noise()
    return "woof"
end

test.suite("class")

test.case("init acts as the constructor", function()
    local animal = Animal("rex")
    test.assert_eq(animal.name, "rex")
    test.assert_eq(animal:describe(), "animal rex")
end)

test.case("multiple inheritance merges methods from all bases", function()
    local dog = Dog("burek")
    test.assert_eq(dog.name, "burek", "init inherited from the first base")
    test.assert_eq(dog:owner(), "adam", "method from the second base")
    test.assert_eq(dog:noise(), "woof", "own method overrides base")
end)

test.case("earlier bases take precedence on method conflicts", function()
    local dog = Dog("azor")
    test.assert_eq(dog:describe(), "animal azor", "TestAnimal wins over TestPet")
end)

test.case("is_instance_of understands the whole hierarchy", function()
    local dog = Dog("saba")
    test.assert_true(is_instance_of(dog, Dog))
    test.assert_true(is_instance_of(dog, Animal))
    test.assert_true(is_instance_of(dog, Pet))
    test.assert_false(is_instance_of(Animal("kitka"), Dog))
end)

test.case("reflection helpers expose class identity", function()
    local dog = Dog("luna")
    test.assert_eq(get_class_of(dog), Dog)
    test.assert_eq(get_class_name_of(dog), "TestDog")
end)

test.case("assert_type accepts matching values and rejects mismatches", function()
    local dog = Dog("misio")
    assert_type(dog, Dog)
    assert_type(dog, Animal)
    assert_type("text", "string")
    test.assert_error(function()
        assert_type(dog, "string")
    end)
    test.assert_error(function()
        assert_type(Animal("filemon"), Dog)
    end)
    test.assert_error(function()
        assert_type(42, Dog)
    end)
end)

test.case("instances of the same class are independent", function()
    local a, b = Animal("a"), Animal("b")
    test.assert_eq(a.name, "a")
    test.assert_eq(b.name, "b")
    a.extra = true
    test.assert_eq(b.extra, nil)
end)

-- lua-lifetime: `release(reason)` is the destructor of every instance.
local Resource = class("TestResource")

---@param log string[]
---@param name string
function Resource:init(log, name)
    self.log = log
    self.name = name
end

---@param reason lifetime.Reason
function Resource:release(reason)
    table.insert(self.log, self.name .. " (" .. reason .. ")")
end

local Quiet = class("TestQuiet")

test.case("release runs as the destructor, with the reason, when an instance is destroyed", function()
    local log = {}
    local r = Resource(log, "r")
    lifetime.destroy(r)
    test.assert_deep_eq(log, {
        "r (destroy)"
    })
    test.assert_false(lifetime.alive(r))
    test.assert_error(function()
        local _ = r.name
    end)
end)

test.case("attach_lifetime anchors the instance and returns it, so a construction chains", function()
    local log = {}
    local owner = Resource(log, "owner")
    local child = Resource(log, "child")
    test.assert_eq(child:attach_lifetime(owner), child, "the same object comes back")
    test.assert_eq(lifetime.format(lifetime.of(child)), "(" .. tostring(owner) .. ", reachable)")
    local chained = Resource(log, "chained"):attach_lifetime(owner, lifetime.reachable)
    test.assert_eq(get_class_name_of(chained), "TestResource")
    test.assert_deep_eq(lifetime.dependents(owner), {
        child,
        chained
    })
    local pinned = Quiet():attach_lifetime(lifetime.pin(owner))
    test.assert_eq(lifetime.format(lifetime.of(pinned)), tostring(owner), "the anchors are lifetime.attach's")
    test.assert_error(function()
        Quiet():attach_lifetime()
    end)
    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "owner (destroy)",
        "chained (anchor)",
        "child (anchor)"
    })
end)

test.case("an anchored instance is released when its anchor dies; a class without release is fine", function()
    local log = {}
    local owner = Resource(log, "owner")
    local child = Resource(log, "child"):attach_lifetime(owner)
    local quiet = Quiet():attach_lifetime(owner)
    lifetime.destroy(owner)
    test.assert_deep_eq(log, {
        "owner (destroy)",
        "child (anchor)"
    }, "the owner's body first, then its dependents")
    test.assert_false(lifetime.alive(child))
    test.assert_false(lifetime.alive(quiet))
end)

test.case("a subclass's release overrides the base's, as any method", function()
    local log = {}
    local Loud = class("TestLoud", Resource)
    ---@param reason lifetime.Reason
    function Loud:release(reason)
        table.insert(self.log, "loud " .. self.name .. " (" .. reason .. ")")
    end
    lifetime.destroy(Loud(log, "l"))
    lifetime.destroy(Resource(log, "r"))
    test.assert_deep_eq(log, {
        "loud l (destroy)",
        "r (destroy)"
    })
end)

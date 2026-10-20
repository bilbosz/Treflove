local test = require("tests.lib.test")
local lifetime = require("lifetime")
local Tree = require("utils.tree")

---@class TestNode: Tree
---@field name string
---@field log string[]
local TestNode = class("TestNode", Tree)

---@param parent Tree|nil
---@param name string
---@param log string[]
function TestNode:init(parent, name, log)
    Tree.init(self, parent)
    self.name = name
    self.log = log
end

---@param reason lifetime.Reason
function TestNode:release(reason)
    table.insert(self.log, self.name .. " (" .. reason .. ")")
    Tree.release(self, reason)
end

test.suite("Tree")

test.case("a destroyed node takes its subtree with it, newest child first, after its own release", function()
    local log = {}
    local a = TestNode(nil, "a", log)
    local b = TestNode(a, "b", log)
    local c = TestNode(a, "c", log)
    local d = TestNode(c, "d", log)
    test.assert_deep_eq(log, {})
    lifetime.destroy(a)
    test.assert_deep_eq(log, {
        "a (destroy)",
        "c (destroy)",
        "d (destroy)",
        "b (destroy)"
    })
    for _, node in ipairs({
        a,
        b,
        c,
        d
    }) do
        test.assert_false(lifetime.alive(node))
    end
end)

test.case("a node destroyed alone leaves its parent's children; the parent lives", function()
    local log = {}
    local a = TestNode(nil, "a", log)
    local b = TestNode(a, "b", log)
    local c = TestNode(a, "c", log)
    lifetime.destroy(b)
    test.assert_deep_eq(log, {
        "b (destroy)"
    })
    test.assert_deep_eq(a:get_children(), {
        c
    })
    test.assert_true(lifetime.alive(a))
    test.assert_true(lifetime.alive(c))
end)

test.case("a subtree detached before its parent dies survives it", function()
    local log = {}
    local a = TestNode(nil, "a", log)
    local b = TestNode(a, "b", log)
    local c = TestNode(b, "c", log)
    b:set_parent(nil)
    lifetime.destroy(a)
    test.assert_deep_eq(log, {
        "a (destroy)"
    })
    test.assert_true(lifetime.alive(b))
    test.assert_true(lifetime.alive(c))
    test.assert_eq(b:get_parent(), nil)
end)

test.case("a child that is also anchored to its parent dies once, in the tree's pass", function()
    local log = {}
    local a = TestNode(nil, "a", log)
    local b = TestNode(a, "b", log):attach_lifetime(a)
    lifetime.destroy(a)
    test.assert_deep_eq(log, {
        "a (destroy)",
        "b (destroy)"
    })
    test.assert_false(lifetime.alive(b))
end)

test.case("a node the collector finds takes its subtree too", function()
    local log = {}
    local holder = {}
    do
        local a = lifetime.attach(TestNode(nil, "a", log), lifetime.reachable)
        TestNode(a, "b", log)
        holder.weak = setmetatable({
            a
        }, {
            __mode = "v"
        })
    end
    collectgarbage("collect")
    collectgarbage("collect")
    test.assert_deep_eq(log, {
        "a (unreachable)",
        "b (destroy)"
    })
    test.assert_eq(holder.weak[1], nil)
end)

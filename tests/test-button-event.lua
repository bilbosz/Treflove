local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Aabb = require("utils.aabb")
local Button = require("ui.button")
local ButtonEventManager = require("ui.button-event")
local Input = require("ui.input")

-- Minimal stand-in for a Control (the real one needs `love.math`): only what
-- the button manager's tree walk looks at. It owns a Button and logs every
-- button event it receives into a shared log as "name:event".
---@class TestButtonControl
---@field name string
---@field visible boolean
---@field button Button
---@field log string[]
---@field private _aabb Aabb
---@field private _children TestButtonControl[]
local TestButtonControl = class("TestButtonControl")

---@param name string
---@param log string[]
---@param x number
---@param y number
---@param w number
---@param h number
---@param children TestButtonControl[]|nil
function TestButtonControl:init(name, log, x, y, w, h, children)
    self.name = name
    self.log = log
    self.visible = true
    self._aabb = Aabb()
    self._aabb:set_position_and_size(x, y, w, h)
    self._children = children or {}
    local button = Button()
    self.button = button
    button.selected:register(self, self.on_selected)
    button.unselected:register(self, self.on_unselected)
    button.pointer_entered:register(self, self.on_pointer_entered)
    button.pointer_left:register(self, self.on_pointer_left)
    button.clicked:register(self, self.on_clicked)
end

---@return boolean
function TestButtonControl:is_visible()
    return self.visible
end

---@return Aabb
function TestButtonControl:get_global_recursive_aabb()
    return self._aabb
end

---@return TestButtonControl[]
function TestButtonControl:get_children()
    return self._children
end

---@param event string
function TestButtonControl:record(event)
    table.insert(self.log, self.name .. ":" .. event)
end

function TestButtonControl:on_selected()
    self:record("selected")
end

function TestButtonControl:on_unselected()
    self:record("unselected")
end

function TestButtonControl:on_pointer_entered()
    self:record("entered")
end

function TestButtonControl:on_pointer_left()
    self:record("left")
end

function TestButtonControl:on_clicked()
    self:record("clicked")
end

-- A fake control that is an `Input`, so the manager's read-only check applies.
---@class TestButtonInput: TestButtonControl, Input
---@field read_only boolean
local TestButtonInput = class("TestButtonInput", TestButtonControl, Input)

---@param name string
---@param log string[]
---@param x number
---@param y number
---@param w number
---@param h number
---@param children TestButtonControl[]|nil
function TestButtonInput:init(name, log, x, y, w, h, children)
    TestButtonControl.init(self, name, log, x, y, w, h, children)
    self.read_only = false
end

---@return boolean
function TestButtonInput:is_read_only()
    return self.read_only
end

---@class TestButtonTree
---@field log string[]
---@field root TestButtonControl 0..100 square, not registered
---@field a TestButtonControl 0..40 square
---@field b TestButtonControl 50..90 square
---@field input TestButtonInput 0..40 x 60..100
---@field inner TestButtonControl 10..30 x 70..90, child of input
---@field manager ButtonEventManager a, b, input and inner registered

-- root      (0..100)
--   a       (0..40, 0..40)
--   b       (50..90, 50..90)
--   input   (0..40, 60..100)
--     inner (10..30, 70..90)
---@return TestButtonTree
local function _make_tree()
    local log = {}
    local a = TestButtonControl("a", log, 0, 0, 40, 40)
    local b = TestButtonControl("b", log, 50, 50, 40, 40)
    local inner = TestButtonControl("inner", log, 10, 70, 20, 20)
    local input = TestButtonInput("input", log, 0, 60, 40, 40, {
        inner
    })
    local root = TestButtonControl("root", log, 0, 0, 100, 100, {
        a,
        b,
        input
    })
    local app_mock = mocks.install_app()
    app_mock.root = root --[[@as Control]]
    local manager = ButtonEventManager()
    for _, ctrl in ipairs({
        a,
        b,
        input,
        inner
    }) do
        manager:register(ctrl --[[@as Control]] , ctrl.button)
    end
    return {
        log = log,
        root = root,
        a = a,
        b = b,
        input = input,
        inner = inner,
        manager = manager
    }
end

test.suite("ButtonEventManager")

test.case("press and release over the same control selects, unselects and clicks it", function()
    local tree = _make_tree()

    tree.manager:dispatch_pointer_down(20, 20, 1)
    test.assert_true(tree.a.button:is_selected())
    tree.manager:dispatch_pointer_up(20, 20, 1)

    test.assert_false(tree.a.button:is_selected())
    test.assert_deep_eq(tree.log, {
        "a:selected",
        "a:unselected",
        "a:clicked"
    })
end)

test.case("release over another control does not click and ends the selection", function()
    local tree = _make_tree()

    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:dispatch_pointer_up(70, 70, 1)
    -- a new press is accepted (the manager asserts no selection is pending)
    tree.manager:dispatch_pointer_down(70, 70, 1)
    tree.manager:dispatch_pointer_up(70, 70, 1)

    test.assert_deep_eq(tree.log, {
        "a:selected",
        "b:selected",
        "b:unselected",
        "b:clicked"
    })
end)

test.case("press outside every registered control does nothing", function()
    local tree = _make_tree()

    tree.manager:dispatch_pointer_down(45, 45, 1)
    tree.manager:dispatch_pointer_up(20, 20, 1)

    test.assert_deep_eq(tree.log, {})
end)

test.case("moves enter and leave the control under the pointer", function()
    local tree = _make_tree()

    tree.manager:dispatch_pointer_move(20, 20, nil)
    test.assert_true(tree.a.button:is_hovered())
    tree.manager:dispatch_pointer_move(25, 25, nil)
    tree.manager:dispatch_pointer_move(70, 70, nil)
    test.assert_false(tree.a.button:is_hovered())
    test.assert_true(tree.b.button:is_hovered())
    tree.manager:dispatch_pointer_move(45, 45, nil)
    test.assert_false(tree.b.button:is_hovered())

    test.assert_deep_eq(tree.log, {
        "a:entered",
        "a:left",
        "b:entered",
        "b:left"
    })
end)

test.case("dragging off unselects, dragging back re-selects, release clicks", function()
    local tree = _make_tree()

    tree.manager:dispatch_pointer_move(20, 20, nil)
    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:dispatch_pointer_move(70, 70, 1)
    test.assert_false(tree.a.button:is_selected())
    tree.manager:dispatch_pointer_move(20, 20, 1)
    test.assert_true(tree.a.button:is_selected())
    tree.manager:dispatch_pointer_up(20, 20, 1)

    test.assert_deep_eq(tree.log, {
        "a:entered",
        "a:selected",
        "a:unselected",
        "a:left",
        "b:entered",
        "a:selected",
        "b:left",
        "a:entered",
        "a:unselected",
        "a:clicked"
    })
end)

test.case("read-only inputs and their subtrees are ignored", function()
    local tree = _make_tree()
    tree.input.read_only = true

    tree.manager:dispatch_pointer_move(20, 80, nil)
    tree.manager:dispatch_pointer_down(20, 80, 1)
    tree.manager:dispatch_pointer_up(20, 80, 1)
    test.assert_deep_eq(tree.log, {})

    -- once writable, the registered input wins over its registered child
    tree.input.read_only = false
    tree.manager:dispatch_pointer_down(20, 80, 1)
    tree.manager:dispatch_pointer_up(20, 80, 1)
    test.assert_deep_eq(tree.log, {
        "input:selected",
        "input:unselected",
        "input:clicked"
    })
end)

test.case("invisible controls are skipped, overlaps go to the first control in tree order", function()
    local tree = _make_tree()
    -- move b over a; a comes first among root's children
    tree.b:get_global_recursive_aabb():set_position_and_size(0, 0, 40, 40)

    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:dispatch_pointer_up(20, 20, 1)
    tree.a.visible = false
    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:dispatch_pointer_up(20, 20, 1)

    test.assert_deep_eq(tree.log, {
        "a:selected",
        "a:unselected",
        "a:clicked",
        "b:selected",
        "b:unselected",
        "b:clicked"
    })
end)

test.case("unregistered controls are not reached", function()
    local tree = _make_tree()
    tree.manager:unregister(tree.a --[[@as Control]] )

    tree.manager:dispatch_pointer_move(20, 20, nil)
    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:dispatch_pointer_up(20, 20, 1)

    test.assert_deep_eq(tree.log, {})
end)

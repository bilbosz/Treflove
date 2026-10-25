local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Aabb = require("utils.aabb")
local Button = require("ui.button")
local ButtonEventManager = require("ui.button-event")
local Input = require("ui.input")

---@class TestButtonControl: Control
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
    app_mock.root = root
    local manager = ButtonEventManager()
    for _, ctrl in ipairs({
        a,
        b,
        input,
        inner
    }) do
        manager:register(ctrl, ctrl.button)
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
    tree.manager:unregister(tree.a)

    tree.manager:dispatch_pointer_move(20, 20, nil)
    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:dispatch_pointer_up(20, 20, 1)

    test.assert_deep_eq(tree.log, {})
end)

test.case("unregistering the control under the pointer leaves it at once; later moves do not reach it", function()
    local tree = _make_tree()
    tree.manager:dispatch_pointer_move(20, 20, nil)
    tree.manager:unregister(tree.a)
    test.assert_false(tree.a.button:is_hovered())
    tree.manager:dispatch_pointer_move(70, 70, nil)

    test.assert_deep_eq(tree.log, {
        "a:entered",
        "a:left",
        "b:entered"
    })
end)

test.case("unregistering a pressed control unselects and leaves it; the release clicks nothing", function()
    local tree = _make_tree()
    tree.manager:dispatch_pointer_move(20, 20, nil)
    tree.manager:dispatch_pointer_down(20, 20, 1)
    tree.manager:unregister(tree.a)
    tree.manager:dispatch_pointer_up(20, 20, 1)
    tree.manager:dispatch_pointer_down(70, 70, 1)

    test.assert_deep_eq(tree.log, {
        "a:entered",
        "a:selected",
        "a:unselected",
        "a:left",
        "b:selected"
    })
end)

test.case("a control unregistered by its own click is left once, after the click", function()
    local tree = _make_tree()
    local manager = tree.manager
    ---@param a TestButtonControl
    local function record_and_unregister(a)
        a:record("clicked")
        manager:unregister(a)
    end
    tree.a.button.clicked:register(tree.a, record_and_unregister)
    manager:dispatch_pointer_move(20, 20, nil)
    manager:dispatch_pointer_down(20, 20, 1)
    manager:dispatch_pointer_up(20, 20, 1)
    manager:dispatch_pointer_move(70, 70, nil)

    test.assert_deep_eq(tree.log, {
        "a:entered",
        "a:selected",
        "a:unselected",
        "a:clicked",
        "a:left",
        "b:entered"
    })
end)

test.case("only the left mouse button or a touch presses; another mouse button hovers and clicks nothing", function()
    local tree = _make_tree()
    local manager = tree.manager
    manager:dispatch_pointer_move(20, 20, nil)
    manager:dispatch_pointer_down(20, 20, 3)
    manager:dispatch_pointer_move(21, 21, 3)
    manager:dispatch_pointer_up(21, 21, 3)
    test.assert_deep_eq(tree.log, {
        "a:entered"
    })

    manager:dispatch_pointer_down(20, 20, 1)
    manager:dispatch_pointer_up(20, 20, 3)
    test.assert_true(tree.a.button:is_selected(), "a release of another button keeps the press")
    manager:dispatch_pointer_up(20, 20, 1)

    ---@diagnostic disable-next-line: param-type-mismatch
    local touch = setmetatable({}, {}) --[[@as lightuserdata]]
    manager:dispatch_pointer_down(70, 70, touch)
    manager:dispatch_pointer_up(70, 70, touch)

    test.assert_deep_eq(tree.log, {
        "a:entered",
        "a:selected",
        "a:unselected",
        "a:clicked",
        "b:selected",
        "b:unselected",
        "b:clicked"
    })
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Control = require("controls.control")
local SeekBar = require("ui.seek-bar")

local LEFT = Consts.LEFT_MOUSE_BUTTON
local LENGTH, MARGIN = Consts.SCROLL_VIEW_INDICATOR_LENGTH, Consts.SCROLL_VIEW_INDICATOR_MARGIN

---@class TestSeekBarSetup
---@field app AppMock
---@field root Control
---@field bar SeekBar 200 wide at (50, 50) under the root: its indicator travels 140
---@field sought number[] Every fraction the bar triggered, in order
---@field listener table The owner of the `sought` handler

local Y = 50 + MARGIN + 1

---@param lx number Along the bar, in its coordinates
---@return number
local function x_at(lx)
    return 50 + lx
end

---@return TestSeekBarSetup
local function setup()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local root = Control()
    app_mock.root = root
    local bar = SeekBar(root, 200)
    bar:set_position(50, 50)
    local sought = {}
    local listener = {}
    ---@param _ table
    ---@param fraction number
    local function on_sought(_, fraction)
        table.insert(sought, fraction)
    end
    bar.sought:register(listener, on_sought)
    return {
        app = app_mock,
        root = root,
        bar = bar,
        sought = sought,
        listener = listener
    }
end

---@param bar SeekBar
---@return Rectangle
local function indicator(bar)
    ---@diagnostic disable-next-line: invisible
    return bar._indicator
end

test.suite("SeekBar")

test.case("is as tall as the scroll view's indicator with its margins, the indicator at the start", function()
    local s = setup()
    test.assert_deep_eq({
        s.bar:get_size()
    }, {
        200,
        Consts.SCROLL_VIEW_INDICATOR_THICKNESS + 2 * MARGIN
    })
    test.assert_eq(s.bar:get_fraction(), 0)
    test.assert_deep_eq({
        indicator(s.bar):get_position()
    }, {
        0,
        MARGIN
    })
    lifetime.destroy(s.root)
end)

test.case("a fraction places the indicator along its travel and is clamped", function()
    local s = setup()
    s.bar:set_fraction(0.5)
    test.assert_deep_eq({
        indicator(s.bar):get_position()
    }, {
        70,
        MARGIN
    })
    s.bar:set_fraction(1.5)
    test.assert_eq(s.bar:get_fraction(), 1)
    test.assert_eq((indicator(s.bar):get_position()), 200 - LENGTH, "at the end of the bar")
    s.bar:set_fraction(-0.5)
    test.assert_eq(s.bar:get_fraction(), 0)
    test.assert_deep_eq(s.sought, {}, "setting the fraction seeks nothing")
    lifetime.destroy(s.root)
end)

test.case("a press holds the pointer and puts the indicator's center under it", function()
    local s = setup()
    local manager = s.app.pointer_event_manager
    manager:dispatch_pointer_down(x_at(100), Y, LEFT)
    test.assert_true(s.bar:is_dragging())
    test.assert_eq(manager:get_captor(LEFT), s.bar, "holds the pointer")
    test.assert_near(s.bar:get_fraction(), 0.5)
    test.assert_deep_eq(s.sought, {
        0.5
    })
    manager:dispatch_pointer_up(x_at(100), Y, LEFT)
    test.assert_false(s.bar:is_dragging())
    test.assert_eq(manager:get_captor(LEFT), nil)
    test.assert_deep_eq(s.sought, {
        0.5
    }, "the release seeks nothing more")
    lifetime.destroy(s.root)
end)

test.case("a drag seeks along the pointer's path, also outside the bar, clamped to its ends", function()
    local s = setup()
    local manager = s.app.pointer_event_manager
    manager:dispatch_pointer_down(x_at(30), Y, LEFT)
    manager:dispatch_pointer_move(x_at(44), Y, nil)
    manager:dispatch_pointer_move(x_at(1000), 400, nil)
    manager:dispatch_pointer_move(x_at(-1000), -400, nil)
    manager:dispatch_pointer_up(x_at(-1000), -400, LEFT)
    test.assert_eq(#s.sought, 4)
    test.assert_near(s.sought[1], 0)
    test.assert_near(s.sought[2], 0.1)
    test.assert_eq(s.sought[3], 1)
    test.assert_eq(s.sought[4], 0)
    test.assert_false(s.bar:is_dragging(), "released outside the bar")

    manager:dispatch_pointer_move(x_at(100), Y, nil)
    test.assert_eq(#s.sought, 4, "a move after the release seeks nothing")
    lifetime.destroy(s.root)
end)

test.case("another button, or a press outside the bar, does not seek and passes through", function()
    local s = setup()
    local manager = s.app.pointer_event_manager
    ---@type string[]
    local log = {}
    ---@param _ Control
    ---@param _x number
    ---@param _y number
    ---@param id PointerId
    local function on_root_down(_, _x, _y, id)
        table.insert(log, "root down " .. tostring(id))
    end
    manager.pointer_down:register(s.root, on_root_down)

    manager:dispatch_pointer_down(x_at(100), Y, Consts.SCROLL_VIEW_DRAG_BUTTON)
    manager:dispatch_pointer_up(x_at(100), Y, Consts.SCROLL_VIEW_DRAG_BUTTON)
    manager:dispatch_pointer_down(x_at(100), 10, LEFT)
    manager:dispatch_pointer_up(x_at(100), 10, LEFT)
    test.assert_deep_eq(s.sought, {})
    test.assert_false(s.bar:is_dragging())

    manager:dispatch_pointer_down(x_at(100), Y, LEFT)
    manager:dispatch_pointer_up(x_at(100), Y, LEFT)
    test.assert_deep_eq(log, {
        "root down 3",
        "root down 1"
    }, "the left press on the bar is consumed, the others reach the root")
    lifetime.destroy(s.root)
end)

test.case("a bar that cannot seek hides its indicator and lets presses through", function()
    local s = setup()
    local manager = s.app.pointer_event_manager
    local root_downs = 0
    ---@param _ Control
    local function on_root_down(_)
        root_downs = root_downs + 1
    end
    manager.pointer_down:register(s.root, on_root_down)

    s.bar:set_seekable(false)
    test.assert_false(s.bar:is_seekable())
    test.assert_false(indicator(s.bar):is_visible())
    manager:dispatch_pointer_down(x_at(100), Y, LEFT)
    manager:dispatch_pointer_up(x_at(100), Y, LEFT)
    test.assert_deep_eq(s.sought, {})
    test.assert_eq(root_downs, 1)

    s.bar:set_seekable(true)
    test.assert_true(indicator(s.bar):is_visible())
    manager:dispatch_pointer_down(x_at(100), Y, LEFT)
    test.assert_true(s.bar:is_dragging())
    s.bar:set_seekable(false)
    test.assert_false(s.bar:is_dragging(), "the drag ends with the seeking")
    test.assert_eq(manager:get_captor(LEFT), nil, "and lets go of the pointer")
    manager:dispatch_pointer_move(x_at(150), Y, LEFT)
    test.assert_deep_eq(s.sought, {
        0.5
    })
    lifetime.destroy(s.root)
end)

test.case("the bar's death ends its registrations and lets go of the pointer", function()
    local s = setup()
    local manager = s.app.pointer_event_manager
    manager:dispatch_pointer_down(x_at(100), Y, LEFT)
    lifetime.destroy(s.bar)
    test.assert_deep_eq(s.root:get_children(), {})
    test.assert_eq(manager.pointer_down:get_handler(s.bar), nil)
    test.assert_eq(manager.pointer_move:get_handler(s.bar), nil)
    test.assert_eq(manager.pointer_up:get_handler(s.bar), nil)
    manager:dispatch_pointer_up(x_at(100), Y, LEFT)
    test.assert_eq(manager:get_captor(LEFT), nil)
    lifetime.destroy(s.root)
end)

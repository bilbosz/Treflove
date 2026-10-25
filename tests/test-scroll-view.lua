local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")
local ScrollView = require("ui.scroll-view")

local DRAG = Consts.SCROLL_VIEW_DRAG_BUTTON
local MARGIN, LENGTH, THICKNESS = Consts.SCROLL_VIEW_INDICATOR_MARGIN, Consts.SCROLL_VIEW_INDICATOR_LENGTH, Consts.SCROLL_VIEW_INDICATOR_THICKNESS

---@class TestScrollViewSetup
---@field app AppMock
---@field root Control
---@field view ScrollView A 100 x 200 view at (50, 50) under the root
---@field content Control The view's content

---@param content_w number
---@param content_h number
---@param with_indicators boolean|nil
---@return TestScrollViewSetup
local function setup(content_w, content_h, with_indicators)
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local root = Control()
    app_mock.root = root
    local view = ScrollView(root, 100, 200, with_indicators)
    view:set_position(50, 50)
    view:set_content_size(content_w, content_h)
    return {
        app = app_mock,
        root = root,
        view = view,
        content = view:get_content()
    }
end

---@param s TestScrollViewSetup
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
local function drag(s, x0, y0, x1, y1)
    local manager = s.app.pointer_event_manager
    manager:dispatch_pointer_down(x0, y0, DRAG)
    manager:dispatch_pointer_move(x1, y1, nil)
    manager:dispatch_pointer_up(x1, y1, DRAG)
end

---@param view ScrollView
---@return Rectangle vertical
---@return Rectangle horizontal
local function indicators(view)
    ---@diagnostic disable-next-line: invisible
    return assert(view._vertical_indicator), assert(view._horizontal_indicator)
end

test.suite("ScrollView")

test.case("content that fits does not scroll and shows no indicator", function()
    local s = setup(80, 150, true)
    test.assert_deep_eq({
        s.view:get_max_scroll()
    }, {
        0,
        0
    })
    drag(s, 100, 200, 60, 100)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        0
    })
    test.assert_deep_eq({
        s.content:get_position()
    }, {
        0,
        0
    })
    local vertical, horizontal = indicators(s.view)
    test.assert_false(vertical:is_visible())
    test.assert_false(horizontal:is_visible())
    lifetime.destroy(s.root)
end)

test.case("a drag with the drag button moves the content by the pointer's path, no further than its edges", function()
    local s = setup(100, 500)
    local manager = s.app.pointer_event_manager

    manager:dispatch_pointer_down(100, 200, DRAG)
    test.assert_true(s.view:is_dragging())
    test.assert_eq(manager:get_captor(DRAG), s.view, "holds the pointer")
    manager:dispatch_pointer_move(100, 170, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        30
    })
    test.assert_deep_eq({
        s.content:get_position()
    }, {
        0,
        -30
    })

    manager:dispatch_pointer_move(100, 190, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        10
    }, "back up along the same path")

    manager:dispatch_pointer_move(100, 240, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        0
    }, "stops at the top")

    manager:dispatch_pointer_move(100, -400, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        300
    }, "stops at the bottom: the content overflows the view by 300")

    manager:dispatch_pointer_up(100, -400, DRAG)
    test.assert_false(s.view:is_dragging())
    test.assert_eq(manager:get_captor(DRAG), nil)
    manager:dispatch_pointer_move(100, 100, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        300
    }, "a move after the release does not scroll")
    lifetime.destroy(s.root)
end)

test.case("the drag follows the pointer out of the view, where it is released", function()
    local s = setup(300, 200)
    local manager = s.app.pointer_event_manager

    manager:dispatch_pointer_down(140, 100, DRAG)
    manager:dispatch_pointer_move(600, 100, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        0
    }, "dragged to the right: the content is at its left edge already")
    manager:dispatch_pointer_move(500, 100, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        100,
        0
    }, "a move far outside the view still drags")
    manager:dispatch_pointer_up(500, 100, DRAG)
    test.assert_false(s.view:is_dragging(), "released outside the view")

    manager:dispatch_pointer_move(400, 100, nil)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        100,
        0
    })
    lifetime.destroy(s.root)
end)

test.case("another button, or a press outside the view, does not drag and passes through", function()
    local s = setup(100, 500)
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

    manager:dispatch_pointer_down(100, 200, Consts.LEFT_MOUSE_BUTTON)
    manager:dispatch_pointer_move(100, 100, nil)
    manager:dispatch_pointer_up(100, 100, Consts.LEFT_MOUSE_BUTTON)
    test.assert_false(s.view:is_dragging())
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        0
    })

    manager:dispatch_pointer_down(10, 10, DRAG)
    manager:dispatch_pointer_move(10, 5, nil)
    manager:dispatch_pointer_up(10, 5, DRAG)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        0
    }, "pressed outside the view")

    manager:dispatch_pointer_down(100, 200, DRAG)
    test.assert_deep_eq(log, {
        "root down 1",
        "root down 3"
    }, "the drag press is consumed, the others reach the root")
    lifetime.destroy(s.root)
end)

test.case("what is scrolled out of the view is not hit, what is in it is", function()
    local s = setup(100, 500)
    local manager = s.app.pointer_event_manager
    local item = Rectangle(s.content, 100, 50)
    item:set_position(0, 300)
    ---@type string[]
    local log = {}
    ---@param _ Control
    ---@param x number
    ---@param y number
    local function on_item_down(_, x, y)
        table.insert(log, string.format("item %d,%d", x, y))
    end
    manager.pointer_down:register(item, on_item_down)

    manager:dispatch_pointer_down(100, 375, Consts.LEFT_MOUSE_BUTTON)
    manager:dispatch_pointer_up(100, 375, Consts.LEFT_MOUSE_BUTTON)
    test.assert_deep_eq(log, {}, "below the view, where the item would be unscrolled")

    s.view:set_scroll(0, 300)
    manager:dispatch_pointer_down(100, 75, Consts.LEFT_MOUSE_BUTTON)
    manager:dispatch_pointer_up(100, 75, Consts.LEFT_MOUSE_BUTTON)
    test.assert_deep_eq(log, {
        "item 100,75"
    }, "scrolled into the view")
    lifetime.destroy(s.root)
end)

test.case("the indicators mark how far the content is scrolled along each overflowed edge", function()
    local s = setup(300, 500, true)
    local vertical, horizontal = indicators(s.view)
    test.assert_true(vertical:is_visible())
    test.assert_true(horizontal:is_visible())
    test.assert_deep_eq({
        vertical:get_position()
    }, {
        100 - MARGIN - THICKNESS,
        MARGIN
    })
    test.assert_deep_eq({
        horizontal:get_position()
    }, {
        MARGIN,
        200 - MARGIN - THICKNESS
    })

    s.view:set_scroll(200, 300)
    test.assert_deep_eq({
        vertical:get_position()
    }, {
        100 - MARGIN - THICKNESS,
        200 - MARGIN - LENGTH
    }, "at the end of its track")
    test.assert_deep_eq({
        horizontal:get_position()
    }, {
        100 - MARGIN - LENGTH,
        200 - MARGIN - THICKNESS
    })

    s.view:set_scroll(100, 150)
    local _, vy = vertical:get_position()
    local hx = horizontal:get_position()
    test.assert_near(vy, MARGIN + (200 - 2 * MARGIN - LENGTH) / 2)
    test.assert_near(hx, MARGIN + (100 - 2 * MARGIN - LENGTH) / 2)

    s.view:set_content_size(100, 500)
    test.assert_false(horizontal:is_visible(), "the content fits across now")
    test.assert_true(vertical:is_visible())
    lifetime.destroy(s.root)
end)

test.case("a scroll, a content size and a view size are clamped against each other", function()
    local s = setup(100, 500)
    s.view:set_scroll(-10, 1000)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        300
    })

    s.view:set_size(100, 400)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        100
    }, "a taller view shows more: the scroll is pulled back")

    s.view:set_content_size(100, 420)
    test.assert_deep_eq({
        s.view:get_scroll()
    }, {
        0,
        20
    }, "shorter content too")
    test.assert_deep_eq({
        s.content:get_position()
    }, {
        0,
        -20
    })
    lifetime.destroy(s.root)
end)

test.case("the view's death takes its content and indicators, and ends its registrations", function()
    local s = setup(100, 500, true)
    local item = Rectangle(s.content, 100, 50)
    local vertical, horizontal = indicators(s.view)
    local manager = s.app.pointer_event_manager
    manager:dispatch_pointer_down(100, 200, DRAG)
    lifetime.destroy(s.view)
    test.assert_false(lifetime.alive(s.content))
    test.assert_false(lifetime.alive(item))
    test.assert_false(lifetime.alive(vertical))
    test.assert_false(lifetime.alive(horizontal))
    test.assert_deep_eq(s.root:get_children(), {})
    test.assert_eq(manager.pointer_down:get_handler(s.view), nil)
    test.assert_eq(manager.pointer_move:get_handler(s.view), nil)
    test.assert_eq(manager.pointer_up:get_handler(s.view), nil)
    manager:dispatch_pointer_up(100, 200, DRAG)
    test.assert_eq(manager:get_captor(DRAG), nil, "the dead view let go of the pointer")
    lifetime.destroy(s.root)
end)

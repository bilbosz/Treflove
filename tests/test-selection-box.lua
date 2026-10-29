local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local SelectionBox = require("ui.selection-box")
local SelectionBoxList = require("ui.selection-box-list")
local SelectionBoxRow = require("ui.selection-box-row")
local ScrollView = require("ui.scroll-view")
local TextButton = require("ui.text-button")

local PADDING = Consts.SELECTION_BOX_PADDING
local ARROW_WIDTH = Consts.SELECTION_BOX_ARROW_WIDTH
local ARROW_HEIGHT = Consts.SELECTION_BOX_ARROW_HEIGHT
local X, Y = 100, 100
local WIDTH, HEIGHT = 400, 50
local SCREEN_WIDTH, SCREEN_HEIGHT = 2000, 1500

---@type SelectionOption[]
local OPTIONS = {
    {
        key = "master",
        title = "Game master"
    },
    {
        key = "player",
        title = "Player"
    },
    {
        key = "guest",
        title = "Guest"
    }
}

---@param count integer
---@return SelectionOption[] The keys `o1`.. and the titles `Option 1`..
local function many_options(count)
    ---@type SelectionOption[]
    local options = {}
    for i = 1, count do
        options[i] = {
            key = "o" .. i,
            title = "Option " .. i
        }
    end
    return options
end

---@class TestSelectionBoxSetup
---@field app AppMock
---@field form FormScreen
---@field box SelectionBox At (`X`, `Y`), `WIDTH` by `HEIGHT`
---@field changes integer How many times `on_change` ran

---@param options SelectionOption[]|nil `OPTIONS` by default
---@param y number|nil `Y` by default
---@return TestSelectionBoxSetup
local function setup(options, y)
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    mocks.ensure_love_mouse()
    app_mock.root = Control()
    app_mock.width, app_mock.height = SCREEN_WIDTH, SCREEN_HEIGHT
    local form = FormScreen()
    ---@type TestSelectionBoxSetup
    local s
    local box = SelectionBox(form:get_control(), form, WIDTH, HEIGHT, options or OPTIONS, function()
        s.changes = s.changes + 1
    end)
    box:set_position(X, y or Y)
    s = {
        app = app_mock,
        form = form,
        box = box,
        changes = 0
    }
    form:show()
    return s
end

---@param s TestSelectionBoxSetup
local function finish(s)
    lifetime.destroy(s.form)
end

---@param s TestSelectionBoxSetup
---@param x number
---@param y number
---@param id PointerId
local function press(s, x, y, id)
    s.app.pointer_event_manager:dispatch_pointer_down(x, y, id)
    s.app.button_event_manager:dispatch_pointer_down(x, y, id)
end

---@param s TestSelectionBoxSetup
---@param x number
---@param y number
---@param id PointerId
local function release(s, x, y, id)
    s.app.pointer_event_manager:dispatch_pointer_up(x, y, id)
    s.app.button_event_manager:dispatch_pointer_up(x, y, id)
end

---@param s TestSelectionBoxSetup
---@param x number
---@param y number
local function move(s, x, y)
    s.app.pointer_event_manager:dispatch_pointer_move(x, y, nil)
    s.app.button_event_manager:dispatch_pointer_move(x, y, nil)
end

---@param s TestSelectionBoxSetup
---@param x number
---@param y number
local function click(s, x, y)
    move(s, x, y)
    press(s, x, y, Consts.LEFT_MOUSE_BUTTON)
    release(s, x, y, Consts.LEFT_MOUSE_BUTTON)
end

---@param s TestSelectionBoxSetup
local function click_box(s)
    local min_x, min_y, max_x, max_y = s.box:get_global_aabb():get_bounds()
    click(s, (min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
end

---@param s TestSelectionBoxSetup
---@param name love.KeyConstant
local function key(s, name)
    s.app.keyboard_manager:dispatch_key_pressed(name)
    s.app.keyboard_manager:dispatch_key_released(name)
end

---@param box SelectionBox
---@return SelectionBoxList
local function list_of(box)
    ---@diagnostic disable-next-line: invisible
    return assert(box._list)
end

---@param box SelectionBox
---@return Text
local function title_of(box)
    ---@diagnostic disable-next-line: invisible
    return box._title
end

---@param box SelectionBox
---@return Triangle
local function arrow_of(box)
    ---@diagnostic disable-next-line: invisible
    return box._arrow
end

---@param box SelectionBox
---@return Rectangle
local function background_of(box)
    ---@diagnostic disable-next-line: invisible
    return box._background
end

---@param ctrl Control
---@return number, number The center of its global box
local function center_of(ctrl)
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    return (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
end

---@param s TestSelectionBoxSetup
---@param index integer
local function click_row(s, index)
    click(s, center_of(list_of(s.box):get_rows()[index]))
end

---@param list SelectionBoxList
---@return integer[] The highlighted rows
local function highlighted_rows(list)
    ---@type integer[]
    local rows = {}
    for i, row in ipairs(list:get_rows()) do
        if row:is_highlighted() then
            table.insert(rows, i)
        end
    end
    return rows
end

---@param s TestSelectionBoxSetup
---@return Control|nil
local function last_child(s)
    local children = s.form:get_control():get_children()
    return children[#children]
end

---@param s TestSelectionBoxSetup
---@param list SelectionBoxList
---@return boolean
local function form_holds(s, list)
    return table.find_array_idx(s.form:get_control():get_children(), list) ~= nil
end

test.suite("SelectionBox")

test.case("the box shows the first option's title at the padding and the arrow at the right edge, the title clipped a padding before it", function()
    local s = setup()
    local box = s.box
    test.assert_eq(box:get_selected(), "master")
    local title = title_of(box)
    test.assert_eq(title:get_text(), "Game master")
    test.assert_eq(title:get_scale(), Consts.MENU_FIELD_SCALE)
    test.assert_deep_eq(title:get_color(), Consts.TEXT_INPUT_FOREGROUND_COLOR)

    local arrow = arrow_of(box)
    local arrow_x, arrow_y = arrow:get_position()
    test.assert_eq(arrow_x, WIDTH - PADDING - ARROW_WIDTH)
    test.assert_eq(arrow_y, (HEIGHT - ARROW_HEIGHT) * 0.5)
    test.assert_deep_eq({
        arrow:get_size()
    }, {
        ARROW_WIDTH,
        ARROW_HEIGHT
    })
    test.assert_deep_eq(arrow:get_color(), Consts.TEXT_INPUT_FOREGROUND_COLOR)

    local clip = assert(title:get_parent())
    local clip_x = clip:get_position()
    local clip_width, clip_height = clip:get_size()
    test.assert_eq(clip_x, PADDING)
    test.assert_eq(clip_x + clip_width, arrow_x - PADDING, "the clip ends a padding before the arrow")
    test.assert_eq(clip_height, HEIGHT)
    local _, title_y = title:get_position()
    test.assert_eq(title_y, HEIGHT * 0.5, "vertically centered")
    test.assert_deep_eq(background_of(box):get_color(), Consts.BUTTON_NORMAL_COLOR)
    finish(s)

    local empty = setup({})
    test.assert_eq(empty.box:get_selected(), nil)
    test.assert_eq(title_of(empty.box):get_text(), "")
    empty.box:open()
    test.assert_false(empty.box:is_open(), "nothing to open without options")
    finish(empty)
end)

test.case("set_options keeps the selected key or falls back to the first, closes an open list and never runs on_change", function()
    local s = setup()
    local box = s.box
    box:set_selected("player")
    box:set_options({
        {
            key = "guest",
            title = "Guest"
        },
        {
            key = "player",
            title = "A player"
        }
    })
    test.assert_eq(box:get_selected(), "player")
    test.assert_eq(title_of(box):get_text(), "A player")

    box:open()
    local list = list_of(box)
    box:set_options(OPTIONS)
    test.assert_false(box:is_open())
    test.assert_false(lifetime.alive(list))
    test.assert_eq(box:get_selected(), "player")

    box:set_options({
        {
            key = "guest",
            title = "Guest"
        }
    })
    test.assert_eq(box:get_selected(), "guest", "the selected key is gone: the first option")
    box:set_options({})
    test.assert_eq(box:get_selected(), nil)
    test.assert_eq(title_of(box):get_text(), "")
    test.assert_eq(s.changes, 0)

    local options = box:get_options()
    test.assert_deep_eq(options, {})
    box:set_options(OPTIONS)
    options = box:get_options()
    options[1].title = "Changed"
    test.assert_eq(box:get_options()[1].title, "Game master", "get_options gives a copy")
    finish(s)
end)

test.case("set_selected selects a known key without on_change and asserts an unknown one", function()
    local s = setup()
    s.box:set_selected("guest")
    test.assert_eq(s.box:get_selected(), "guest")
    test.assert_eq(title_of(s.box):get_text(), "Guest")
    test.assert_error(function()
        s.box:set_selected("nobody")
    end)
    test.assert_eq(s.box:get_selected(), "guest")
    test.assert_eq(s.changes, 0)
    finish(s)
end)

test.case("a click focuses the box and opens the list over the screen, under the box, the selected row highlighted; a second click closes it", function()
    local s = setup()
    local box = s.box
    box:set_selected("player")
    click_box(s)
    test.assert_true(box:is_focused())
    test.assert_true(box:is_open())
    test.assert_deep_eq(background_of(box):get_color(), Consts.BUTTON_SELECT_COLOR)

    local list = list_of(box)
    test.assert_eq(last_child(s), list, "the list is the form control's last child")
    test.assert_deep_eq({
        list:get_position()
    }, {
        0,
        0
    })
    test.assert_deep_eq({
        list:get_size()
    }, {
        SCREEN_WIDTH,
        SCREEN_HEIGHT
    }, "the backdrop covers the screen")
    local frame = list:get_frame()
    test.assert_deep_eq({
        frame:get_position()
    }, {
        X,
        Y + HEIGHT
    }, "under the box")
    test.assert_deep_eq({
        frame:get_size()
    }, {
        WIDTH,
        3 * HEIGHT
    })
    local rows = list:get_rows()
    test.assert_eq(#rows, 3)
    test.assert_eq(get_class_name_of(rows[2]), "SelectionBoxRow")
    test.assert_eq(rows[2]:get_title(), "Player")
    test.assert_deep_eq({
        rows[2]:get_size()
    }, {
        WIDTH,
        HEIGHT
    })
    test.assert_deep_eq(highlighted_rows(list), {
        2
    })
    test.assert_true(rows[2]:is_selected())
    test.assert_deep_eq(rows[1]:get_color(), Consts.BUTTON_NORMAL_COLOR)
    test.assert_deep_eq(rows[2]:get_color(), Consts.BUTTON_ACTIVE_HOVER_COLOR)

    click_box(s)
    test.assert_false(box:is_open())
    test.assert_false(lifetime.alive(list))
    test.assert_false(form_holds(s, list))
    test.assert_true(box:is_focused())
    test.assert_eq(s.changes, 0)

    click_box(s)
    test.assert_true(box:is_open(), "a third click opens it again")
    finish(s)
end)

test.case("the list opens above the box without room below it", function()
    local s = setup(nil, SCREEN_HEIGHT - 100)
    click_box(s)
    local frame = list_of(s.box):get_frame()
    test.assert_deep_eq({
        frame:get_position()
    }, {
        X,
        SCREEN_HEIGHT - 100 - 3 * HEIGHT
    })
    finish(s)
end)

test.case("the list is placed by the box's box on screen: inside a scaled and moved parent too", function()
    local s = setup()
    local panel = Control(s.form:get_control(), 1000, 1000)
    panel:set_position(300, 200)
    panel:set_scale(0.5)
    local box = SelectionBox(panel, s.form, WIDTH, HEIGHT, OPTIONS)
    box:set_position(100, 100)
    click_box({
        app = s.app,
        form = s.form,
        box = box,
        changes = 0
    })
    local list = list_of(box)
    test.assert_eq(last_child(s), list)
    local frame = list:get_frame()
    test.assert_deep_eq({
        frame:get_position()
    }, {
        350,
        250 + HEIGHT * 0.5
    })
    test.assert_deep_eq({
        frame:get_size()
    }, {
        WIDTH * 0.5,
        3 * HEIGHT * 0.5
    })
    finish(s)
end)

test.case("more options than the max rows scroll in the list, the selected row scrolled into view", function()
    local count = Consts.SELECTION_BOX_MAX_ROWS + 4
    local s = setup(many_options(count))
    s.box:set_selected("o9")
    click_box(s)
    local list = list_of(s.box)
    local view = list:get_view()
    test.assert_deep_eq({
        list:get_frame():get_size()
    }, {
        WIDTH,
        Consts.SELECTION_BOX_MAX_ROWS * HEIGHT
    })
    test.assert_deep_eq({
        view:get_content_size()
    }, {
        WIDTH,
        count * HEIGHT
    })
    test.assert_deep_eq({
        view:get_scroll()
    }, {
        0,
        (9 - Consts.SELECTION_BOX_MAX_ROWS) * HEIGHT
    }, "row 9 is the last in view")
    test.assert_deep_eq(highlighted_rows(list), {
        9
    })
    ---@diagnostic disable-next-line: invisible
    local indicator = assert(view._vertical_indicator)
    test.assert_true(indicator:is_visible())
    test.assert_deep_eq(indicator:get_color(), Consts.TEXT_INPUT_FOREGROUND_COLOR, "the indicator shows in the text color over the rows")

    click_row(s, 4)
    test.assert_eq(s.box:get_selected(), "o4", "a row scrolled into place is picked by where it is shown")
    finish(s)
end)

test.case("a press on a row picks it, runs on_change once and closes; the selected row picks nothing new", function()
    local s = setup()
    click_box(s)
    local list = list_of(s.box)
    click_row(s, 2)
    test.assert_eq(s.box:get_selected(), "player")
    test.assert_eq(s.changes, 1)
    test.assert_eq(title_of(s.box):get_text(), "Player")
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))
    test.assert_false(form_holds(s, list))

    click_box(s)
    click_row(s, 2)
    test.assert_false(s.box:is_open())
    test.assert_eq(s.changes, 1, "the same option: no change")
    finish(s)
end)

test.case("on_change runs after the list is gone, with the new selection", function()
    local s = setup()
    ---@type {[1]: string|nil, [2]: boolean}[]
    local seen = {}
    local box = SelectionBox(s.form:get_control(), s.form, WIDTH, HEIGHT, OPTIONS, function()
        table.insert(seen, {
            s.box:get_selected(),
            s.box:is_open()
        })
    end)
    box:set_position(X, Y)
    s.box = box
    click_box(s)
    click_row(s, 3)
    test.assert_deep_eq(seen, {
        {
            "guest",
            false
        }
    })
    finish(s)
end)

test.case("a press outside the list closes it without a change and reaches nothing under it", function()
    local s = setup()
    local clicks = 0
    local other = TextButton(s.form:get_control(), s.form, "Other", function()
        clicks = clicks + 1
    end)
    other:set_position(1000, 600)
    click_box(s)
    local list = list_of(s.box)
    click(s, center_of(other))
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))
    test.assert_eq(clicks, 0, "the backdrop took the click")
    test.assert_false(other:is_hovered(), "nor was it hovered meanwhile")
    test.assert_eq(s.box:get_selected(), "master")
    test.assert_eq(s.changes, 0)

    click(s, center_of(other))
    test.assert_eq(clicks, 1, "with the list gone the button is reached")
    finish(s)
end)

test.case("a press of another mouse button outside closes the list too; the drag button over the list scrolls it", function()
    local s = setup(many_options(10))
    click_box(s)
    local list = list_of(s.box)
    local x, y = center_of(list:get_frame())
    press(s, x, y, Consts.SCROLL_VIEW_DRAG_BUTTON)
    s.app.pointer_event_manager:dispatch_pointer_move(x, y - HEIGHT, nil)
    release(s, x, y - HEIGHT, Consts.SCROLL_VIEW_DRAG_BUTTON)
    test.assert_true(s.box:is_open())
    test.assert_deep_eq({
        list:get_view():get_scroll()
    }, {
        0,
        HEIGHT
    })

    press(s, 1500, 1000, 2)
    release(s, 1500, 1000, 2)
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))
    finish(s)
end)

test.case("the wheel over the open list scrolls its rows by a notch's rows and reaches nothing under the list", function()
    local s = setup(many_options(12))
    local manager = s.app.pointer_event_manager
    local page = Control(s.form:get_control(), 2000, 1500)
    local page_wheels = 0
    ---@return boolean|nil
    local function on_page_wheel()
        page_wheels = page_wheels + 1
    end
    manager.wheel:register(page, on_page_wheel)
    manager:set_receive_through(page, true)
    local under = ScrollView(s.form:get_control(), 300, 300)
    under:set_position(1000, 600)
    under:set_content_size(300, 1000)
    under:set_scroll(0, 100)
    click_box(s)
    local list = list_of(s.box)
    local view = list:get_view()
    test.assert_eq(view:get_wheel_step(), HEIGHT * Consts.SELECTION_BOX_WHEEL_ROWS)

    s.app:set_pointer_position(center_of(list:get_frame()))
    manager:dispatch_wheel(0, -1)
    test.assert_deep_eq({
        view:get_scroll()
    }, {
        0,
        Consts.SELECTION_BOX_WHEEL_ROWS * HEIGHT
    })
    test.assert_deep_eq(highlighted_rows(list), {
        1
    }, "the highlight follows a move only")

    s.app:set_pointer_position(center_of(under))
    manager:dispatch_wheel(0, -1)
    test.assert_deep_eq({
        under:get_scroll()
    }, {
        0,
        100
    }, "a scroll view under the backdrop keeps its scroll")
    test.assert_eq(page_wheels, 0, "and a page under it, receiving the pointer events consumed above it, its zoom")
    test.assert_true(s.box:is_open(), "the wheel closes nothing")

    s.box:close()
    manager:dispatch_wheel(0, -1)
    test.assert_deep_eq({
        under:get_scroll()
    }, {
        0,
        160
    }, "with the list gone the wheel reaches it")
    finish(s)
end)

test.case("the pointer over a row highlights it", function()
    local s = setup()
    click_box(s)
    local list = list_of(s.box)
    local rows = list:get_rows()
    move(s, center_of(rows[3]))
    test.assert_deep_eq(highlighted_rows(list), {
        3
    })
    test.assert_deep_eq(rows[3]:get_color(), Consts.BUTTON_HOVER_COLOR)
    test.assert_deep_eq(rows[1]:get_color(), Consts.BUTTON_ACTIVE_COLOR, "the selected row, not highlighted")
    move(s, 1500, 1000)
    test.assert_deep_eq(highlighted_rows(list), {
        3
    }, "off the list the highlight stays")
    finish(s)
end)

test.case("while open Up and Down move the highlight, clamped and scrolled into view, and Return picks it", function()
    local s = setup(many_options(10))
    click_box(s)
    local list = list_of(s.box)
    key(s, "up")
    test.assert_deep_eq(highlighted_rows(list), {
        1
    }, "clamped at the top")
    for _ = 1, 7 do
        key(s, "down")
    end
    test.assert_deep_eq(highlighted_rows(list), {
        8
    })
    test.assert_deep_eq({
        list:get_view():get_scroll()
    }, {
        0,
        2 * HEIGHT
    })
    for _ = 1, 5 do
        key(s, "down")
    end
    test.assert_deep_eq(highlighted_rows(list), {
        10
    }, "clamped at the bottom")
    for _ = 1, 6 do
        key(s, "up")
    end
    test.assert_deep_eq({
        list:get_view():get_scroll()
    }, {
        0,
        3 * HEIGHT
    }, "row 4 is the first in view")
    test.assert_eq(s.box:get_selected(), "o1", "the highlight is no selection")
    test.assert_eq(s.changes, 0)

    key(s, "return")
    test.assert_false(s.box:is_open())
    test.assert_eq(s.box:get_selected(), "o4")
    test.assert_eq(s.changes, 1)
    finish(s)
end)

test.case("a focused closed box opens on Return or Space, and Up and Down change its selection", function()
    local s = setup()
    s.form:focus(s.box)
    key(s, "return")
    test.assert_true(s.box:is_open())
    s.box:close()
    key(s, "space")
    test.assert_true(s.box:is_open())
    s.box:close()

    key(s, "down")
    test.assert_eq(s.box:get_selected(), "player")
    test.assert_eq(title_of(s.box):get_text(), "Player")
    key(s, "down")
    key(s, "down")
    test.assert_eq(s.box:get_selected(), "guest", "clamped at the last")
    test.assert_eq(s.changes, 2)
    key(s, "up")
    key(s, "up")
    key(s, "up")
    test.assert_eq(s.box:get_selected(), "master")
    test.assert_eq(s.changes, 4)
    test.assert_false(s.box:is_open())
    finish(s)
end)

test.case("an unfocused box hears no keys", function()
    local s = setup()
    key(s, "down")
    key(s, "return")
    test.assert_eq(s.box:get_selected(), "master")
    test.assert_false(s.box:is_open())
    finish(s)
end)

test.case("the list closes when the focus moves on, the screen hides or the window is resized", function()
    local s = setup()
    local other = SelectionBox(s.form:get_control(), s.form, WIDTH, HEIGHT, OPTIONS)
    other:set_position(X, 800)
    click_box(s)
    local list = list_of(s.box)
    key(s, "tab")
    test.assert_true(other:is_focused())
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))

    click_box(s)
    list = list_of(s.box)
    s.form:hide()
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))
    s.box:open()
    test.assert_false(s.box:is_open(), "a hidden screen opens nothing")
    s.form:show()

    click_box(s)
    list = list_of(s.box)
    s.app.resize_manager.resized:trigger(1000, 750)
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))
    finish(s)
end)

test.case("a read-only box closes its list, shows the read-only color, takes no focus and opens on nothing", function()
    local s = setup()
    local other = SelectionBox(s.form:get_control(), s.form, WIDTH, HEIGHT, OPTIONS)
    other:set_position(X, 800)
    s.box:open()
    local list = list_of(s.box)
    s.box:set_read_only(true)
    test.assert_false(s.box:is_open())
    test.assert_false(lifetime.alive(list))

    test.assert_deep_eq(background_of(s.box):get_color(), Consts.BUTTON_READ_ONLY_COLOR)
    click_box(s)
    test.assert_false(s.box:is_focused())
    test.assert_false(s.box:is_open())
    s.box:open()
    test.assert_false(s.box:is_open())
    key(s, "tab")
    test.assert_true(other:is_focused())
    key(s, "tab")
    test.assert_true(other:is_focused(), "Tab skips the read-only box")
    test.assert_false(s.box:is_focused())

    s.box:set_read_only(false)
    click_box(s)
    test.assert_true(s.box:is_open())
    finish(s)
end)

---@param log string[]
---@param fn fun()
local function with_release_log(log, fn)
    ---@type table<string, any>
    local classes = {
        SelectionBox = SelectionBox,
        SelectionBoxList = SelectionBoxList,
        SelectionBoxRow = SelectionBoxRow
    }
    ---@type table<string, Destructor>
    local originals = {}
    for name, cls in pairs(classes) do
        ---@type Destructor
        local destructor = cls.release
        originals[name] = destructor
        ---@param self Object
        ---@param reason lifetime.Reason
        cls.release = function(self, reason)
            table.insert(log, name .. ":release(" .. tostring(reason) .. ")")
            destructor(self, reason)
        end
    end
    collectgarbage("stop")
    ---@type boolean, any
    local ok, err = pcall(fn)
    collectgarbage("restart")
    for name, cls in pairs(classes) do
        cls.release = originals[name]
    end
    if not ok then
        error(err, 0)
    end
end

test.case("a box destroyed while open takes its list: off the form's control, its buttons let go", function()
    local s = setup()
    click_box(s)
    local list = list_of(s.box)
    local box = s.box
    local log = {}
    with_release_log(log, function()
        lifetime.destroy(box)
    end)
    test.assert_deep_eq(log, {
        "SelectionBox:release(destroy)",
        "SelectionBoxList:release(anchor)",
        "SelectionBoxRow:release(destroy)",
        "SelectionBoxRow:release(destroy)",
        "SelectionBoxRow:release(destroy)"
    }, "the box, then the list anchored to it with its rows, newest first")
    test.assert_false(lifetime.alive(list))
    test.assert_false(form_holds(s, list))
    test.assert_eq(last_child(s), nil, "the form's control is empty")

    local clicks = 0
    local other = TextButton(s.form:get_control(), s.form, "Other", function()
        clicks = clicks + 1
    end)
    other:set_position(1000, 600)
    click(s, center_of(other))
    test.assert_eq(clicks, 1, "no button of the dead list is in the way")
    finish(s)
end)

test.case("a form destroyed while a list is open takes the list, then the box", function()
    local s = setup()
    click_box(s)
    local list = list_of(s.box)
    local box = s.box
    local log = {}
    with_release_log(log, function()
        lifetime.destroy(s.form)
    end)
    test.assert_deep_eq(log, {
        "SelectionBoxList:release(destroy)",
        "SelectionBoxRow:release(destroy)",
        "SelectionBoxRow:release(destroy)",
        "SelectionBoxRow:release(destroy)",
        "SelectionBox:release(destroy)"
    }, "the screen hides first, which closes the list; then its control tree takes the box")
    test.assert_false(lifetime.alive(list))
    test.assert_false(lifetime.alive(box))
end)

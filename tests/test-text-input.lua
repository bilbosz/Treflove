local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Control = require("controls.control")
local Text = require("controls.text")
local FormScreen = require("ui.form-screen")
local NumberInput = require("ui.number-input")
local TextEventManager = require("ui.text-event")
local TextInput = require("ui.text-input")

local Command = TextEventManager.Command

---The fake text is 10 units per byte, the field's text at the menu scale
local CHAR = 10 * Consts.MENU_FIELD_SCALE
local BULLET = 3 * CHAR
local PADDING = 10
local HEIGHT = 50
local MID_Y = HEIGHT * 0.5

---@class TestTextInputSetup
---@field app AppMock
---@field form FormScreen
---@field field TextInput At (0, 0), `width` by 50, the content at `PADDING`
---@field system TestSystem
---@field inputs integer How many times `on_input` ran
---@field enters integer How many times `on_enter` ran

---@param width number|nil 200 by default
---@param masked boolean|nil
---@return TestTextInputSetup
local function setup(width, masked)
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    mocks.ensure_love_mouse()
    app_mock.root = Control()

    ---@class TestSystem: love.system
    ---@field clipboard string
    local system = {
        clipboard = ""
    }

    ---@param text string
    function system.setClipboardText(text)
        system.clipboard = text
    end

    ---@return string
    function system.getClipboardText()
        return system.clipboard
    end

    app_mock.text_event_manager = TextEventManager(mocks.make_keyboard(), system)
    local form = FormScreen()
    ---@type TestTextInputSetup
    local s
    local field = TextInput(form:get_control(), form, width or 200, HEIGHT, masked, function()
        s.inputs = s.inputs + 1
    end, function()
        s.enters = s.enters + 1
    end)
    s = {
        app = app_mock,
        form = form,
        field = field,
        system = system,
        inputs = 0,
        enters = 0
    }
    form:show()
    return s
end

---@param s TestTextInputSetup
local function finish(s)
    lifetime.destroy(s.form)
end

---@param s TestTextInputSetup
---@param name TextCommand
---@param direction TextDirection|nil
---@param step TextStep|nil
---@param extend boolean|nil
local function command(s, name, direction, step, extend)
    s.app.text_event_manager.commanded:trigger(name, direction, step, extend)
end

---@param s TestTextInputSetup
---@param text string
local function type_text(s, text)
    s.app.text_event_manager:text_input(text)
end

---@param s TestTextInputSetup
---@param x number
---@param y number
---@param id PointerId
local function press(s, x, y, id)
    s.app.pointer_event_manager:dispatch_pointer_down(x, y, id)
    s.app.button_event_manager:dispatch_pointer_down(x, y, id)
end

---@param s TestTextInputSetup
---@param x number
---@param y number
---@param id PointerId
local function release(s, x, y, id)
    s.app.pointer_event_manager:dispatch_pointer_up(x, y, id)
    s.app.button_event_manager:dispatch_pointer_up(x, y, id)
end

---@param s TestTextInputSetup
---@param x number
---@param y number
local function move(s, x, y)
    s.app.pointer_event_manager:dispatch_pointer_move(x, y, nil)
    s.app.button_event_manager:dispatch_pointer_move(x, y, nil)
end

---@param s TestTextInputSetup
---@param x number
local function click(s, x)
    press(s, x, MID_Y, 1)
    release(s, x, MID_Y, 1)
end

---@param index integer A codepoint count
---@return number The global x of the boundary after `index` ASCII characters, with the content unscrolled
local function x_of(index)
    return PADDING + index * CHAR
end

---@param field TextInput
---@return number The caret's x in the content
local function caret_x(field)
    ---@diagnostic disable-next-line: invisible
    return (field._caret:get_position())
end

---@param field TextInput
---@return number The content's offset: how far it is scrolled
local function offset_of(field)
    ---@diagnostic disable-next-line: invisible
    return (field._content:get_position())
end

---@param field TextInput
---@return Rectangle
local function selection_of(field)
    ---@diagnostic disable-next-line: invisible
    return field._selection
end

---@param field TextInput
---@return {[1]: string, [2]: integer, [3]: integer, [4]: integer} The text, the caret, the selection's start and end
local function state(field)
    local low, high = field:get_selection()
    return {
        field:get_text(),
        field:get_caret(),
        low,
        high
    }
end

test.suite("TextInput")

test.case("Text:measure gives the width of a text in the face, in model units", function()
    mocks.ensure_love_graphics()
    local text = Text(nil, "")
    test.assert_eq(text:measure(""), 0)
    test.assert_eq(text:measure("abc"), 30)
    test.assert_eq(text:get_size(), 0, "the control's own text is untouched")
end)

test.case("the caret is drawn at the width of the text before it; a masked field measures the bullets", function()
    local s = setup()
    s.form:focus(s.field)
    type_text(s, "hello")
    test.assert_near(caret_x(s.field), 5 * CHAR, 1e-4)
    command(s, Command.MOVE, -1, "character")
    command(s, Command.MOVE, -1, "character")
    test.assert_near(caret_x(s.field), 3 * CHAR, 1e-4)
    finish(s)

    local m = setup(nil, true)
    m.form:focus(m.field)
    type_text(m, "ab")
    test.assert_near(caret_x(m.field), 2 * BULLET, 1e-4)
    command(m, Command.MOVE, -1, "character")
    test.assert_near(caret_x(m.field), BULLET, 1e-4)
    finish(m)
end)

test.case("the selection rectangle spans the selection under the text, and goes with the selection or the focus", function()
    local s = setup()
    local field = s.field
    local selection = selection_of(field)
    ---@diagnostic disable-next-line: invisible
    local content = field._content
    test.assert_eq(content:get_children()[1], selection, "drawn under the caret and the text")
    test.assert_false(selection:is_enabled())

    s.form:focus(field)
    type_text(s, "hello world")
    command(s, Command.MOVE, -1, "word", true)
    test.assert_true(selection:is_enabled())
    test.assert_near(selection:get_position(), 6 * CHAR, 1e-4)
    test.assert_near(selection:get_size(), 5 * CHAR, 1e-4)
    local _, h = selection:get_size()
    test.assert_eq(h, HEIGHT - 2 * PADDING, "as high as the caret")
    test.assert_deep_eq(selection:get_color(), Consts.TEXT_INPUT_SELECTION_COLOR)

    local other = TextInput(s.form:get_control(), s.form, 200, HEIGHT, false, nil, nil)
    s.form:focus(other)
    test.assert_false(selection:is_enabled(), "an unfocused field shows no selection")
    s.form:focus(field)
    test.assert_true(selection:is_enabled())
    test.assert_near(selection:get_size(), 11 * CHAR, 1e-4, "the focus selected all")
    command(s, Command.MOVE, 1, "character")
    test.assert_false(selection:is_enabled())
    finish(s)
end)

test.case("the content scrolls just enough to keep the caret in the clip, and never leaves space at the right", function()
    local s = setup(60)
    local field = s.field
    local clip_w = 60 - 2 * PADDING
    field:set_text("abcdefghijklmnop")
    local text_w = 16 * CHAR
    test.assert_near(offset_of(field), clip_w - Consts.CARET_WIDTH - text_w, 1e-4, "the caret at the end is just inside")

    s.form:focus(field)
    command(s, Command.MOVE, -1, "line")
    test.assert_eq(offset_of(field), 0)
    command(s, Command.MOVE, 1, "character")
    test.assert_eq(offset_of(field), 0, "a caret within the clip scrolls nothing")
    for _ = 1, 11 do
        command(s, Command.MOVE, 1, "character")
    end
    test.assert_near(offset_of(field), clip_w - Consts.CARET_WIDTH - 12 * CHAR, 1e-4, "the caret went past the right edge")
    local scrolled = offset_of(field)
    command(s, Command.MOVE, -1, "character")
    test.assert_eq(offset_of(field), scrolled, "a caret back inside leaves the scroll")
    command(s, Command.MOVE, 1, "line")
    command(s, Command.DELETE, -1, "character")
    command(s, Command.DELETE, -1, "character")
    command(s, Command.DELETE, -1, "character")
    command(s, Command.DELETE, -1, "character")
    test.assert_near(offset_of(field), clip_w - Consts.CARET_WIDTH - 12 * CHAR, 1e-4, "the shortened text keeps its end at the right edge")

    field:set_text("ab")
    test.assert_eq(offset_of(field), 0, "a narrow text sits at the left")
    finish(s)
end)

test.case("a press focuses the field through the form, places the caret, and its drag selects until the release", function()
    local s = setup()
    local field = s.field
    local other = TextInput(s.form:get_control(), s.form, 200, HEIGHT, false, nil, nil)
    other:set_position(0, 100)
    field:set_text("hello world")
    s.form:focus(other)

    press(s, x_of(4) + 1, MID_Y, 1)
    test.assert_true(field:is_focused())
    test.assert_false(other:is_focused())
    test.assert_deep_eq(state(field), {
        "hello world",
        4,
        4,
        4
    })
    test.assert_eq(s.app.pointer_event_manager:get_captor(1), field)
    move(s, x_of(8) - 0.5, MID_Y)
    test.assert_deep_eq(state(field), {
        "hello world",
        8,
        4,
        8
    })
    move(s, 500, 500)
    test.assert_eq(field:get_caret(), 11, "a drag beyond the field goes on, held by the capture")
    release(s, 500, 500, 1)
    test.assert_eq(s.app.pointer_event_manager:get_captor(1), nil)
    move(s, x_of(2), MID_Y)
    test.assert_eq(field:get_caret(), 11, "a move without a press leaves the caret")
    s.app:advance_time(1)
    press(s, x_of(0) - 5, MID_Y, 1)
    release(s, x_of(0) - 5, MID_Y, 1)
    test.assert_eq(field:get_caret(), 0, "a press left of the text puts the caret at the start")
    finish(s)
end)

test.case("a press with another button passes through, and a read-only field ignores the press", function()
    local s = setup()
    local field = s.field
    field:set_text("hello")
    press(s, x_of(2), MID_Y, Consts.SCROLL_VIEW_DRAG_BUTTON)
    release(s, x_of(2), MID_Y, Consts.SCROLL_VIEW_DRAG_BUTTON)
    test.assert_false(field:is_focused())
    test.assert_eq(field:get_caret(), 5)

    field:set_read_only(true)
    click(s, x_of(2))
    test.assert_false(field:is_focused())
    test.assert_eq(s.app.pointer_event_manager:get_captor(1), nil)
    finish(s)
end)

test.case("Shift and a press extend the selection from the caret", function()
    local s = setup()
    local field = s.field
    field:set_text("hello world")
    click(s, x_of(4))
    s.app.keyboard_manager:dispatch_key_pressed("lshift")
    s.app:advance_time(1)
    click(s, x_of(9))
    s.app.keyboard_manager:dispatch_key_released("lshift")
    test.assert_deep_eq(state(field), {
        "hello world",
        9,
        4,
        9
    })
    finish(s)
end)

test.case("a second press within the interval selects the word, a third everything, a fourth starts over", function()
    local s = setup()
    local field = s.field
    field:set_text("hello world")
    click(s, x_of(8))
    test.assert_deep_eq(state(field), {
        "hello world",
        8,
        8,
        8
    })
    s.app:advance_time(Consts.MULTI_CLICK_INTERVAL * 0.5)
    click(s, x_of(8))
    test.assert_deep_eq(state(field), {
        "hello world",
        11,
        6,
        11
    }, "the word around the caret")
    s.app:advance_time(Consts.MULTI_CLICK_INTERVAL * 0.5)
    click(s, x_of(8))
    test.assert_deep_eq(state(field), {
        "hello world",
        11,
        0,
        11
    })
    s.app:advance_time(Consts.MULTI_CLICK_INTERVAL * 0.5)
    click(s, x_of(3))
    test.assert_deep_eq(state(field), {
        "hello world",
        3,
        3,
        3
    })
    s.app:advance_time(Consts.MULTI_CLICK_INTERVAL * 2)
    click(s, x_of(3))
    test.assert_deep_eq(state(field), {
        "hello world",
        3,
        3,
        3
    }, "a press after the interval is a first press")
    finish(s)
end)

test.case("the focus selects all, so typing replaces the text, and the commands move, delete and select", function()
    local s = setup()
    local field = s.field
    field:set_text("old")
    s.form:focus(field)
    test.assert_deep_eq(state(field), {
        "old",
        3,
        0,
        3
    })
    type_text(s, "n")
    type_text(s, "ew")
    test.assert_eq(field:get_text(), "new")
    test.assert_eq(s.inputs, 2, "on_input ran per edit")
    command(s, Command.MOVE, -1, "line")
    command(s, Command.DELETE, 1, "character")
    test.assert_eq(field:get_text(), "ew")
    command(s, Command.SELECT_ALL)
    test.assert_eq(field:get_selection(), 0)
    command(s, Command.MOVE, 1, "word")
    test.assert_eq(field:get_caret(), 2)
    command(s, Command.ENTER)
    test.assert_eq(s.enters, 1)
    finish(s)
end)

test.case("the clipboard: copy and cut take the selection, paste inserts what is there, a masked field copies nothing", function()
    local s = setup()
    local field = s.field
    s.form:focus(field)
    type_text(s, "hello world")
    command(s, Command.COPY)
    test.assert_eq(s.system.clipboard, "", "nothing selected")
    command(s, Command.MOVE, -1, "word", true)
    command(s, Command.COPY)
    test.assert_eq(s.system.clipboard, "world")
    test.assert_eq(field:get_text(), "hello world")
    command(s, Command.CUT)
    test.assert_eq(field:get_text(), "hello ")
    command(s, Command.PASTE)
    command(s, Command.PASTE)
    test.assert_eq(field:get_text(), "hello worldworld")
    s.system.clipboard = ""
    command(s, Command.SELECT_ALL)
    command(s, Command.PASTE)
    test.assert_eq(field:get_text(), "hello worldworld", "an empty clipboard pastes nothing")
    test.assert_deep_eq({
        field:get_selection()
    }, {
        0,
        16
    }, "the selection stays")
    finish(s)

    local m = setup(nil, true)
    m.form:focus(m.field)
    type_text(m, "secret")
    command(m, Command.SELECT_ALL)
    command(m, Command.COPY)
    command(m, Command.CUT)
    test.assert_eq(m.system.clipboard, "")
    test.assert_eq(m.field:get_text(), "secret", "a cut that copies nothing deletes nothing")
    finish(m)
end)

test.case("undo and redo go to the buffer; a word delete in a masked field clears it", function()
    local s = setup()
    s.form:focus(s.field)
    type_text(s, "ab")
    type_text(s, " ")
    type_text(s, "c")
    command(s, Command.UNDO)
    test.assert_eq(s.field:get_text(), "ab ")
    command(s, Command.UNDO)
    test.assert_eq(s.field:get_text(), "ab")
    command(s, Command.REDO)
    test.assert_eq(s.field:get_text(), "ab ")
    finish(s)

    local m = setup(nil, true)
    m.form:focus(m.field)
    type_text(m, "secret word")
    command(m, Command.MOVE, -1, "line")
    command(m, Command.DELETE, -1, "word")
    test.assert_eq(m.field:get_text(), "")
    test.assert_eq(m.inputs, 2)
    finish(m)
end)

test.case("a number input refuses every edit that is not a number, an empty text or a lone minus", function()
    local s = setup()
    local field = NumberInput(s.form:get_control(), s.form, 200, HEIGHT, function()
        s.inputs = s.inputs + 1
    end, nil)
    test.assert_eq(field:get_number(), 0)
    s.form:focus(field)
    type_text(s, "1")
    type_text(s, "a")
    type_text(s, ".")
    type_text(s, "5")
    test.assert_eq(field:get_text(), "1.5")
    test.assert_eq(field:get_number(), 1.5)
    test.assert_eq(s.inputs, 3)

    command(s, Command.SELECT_ALL)
    command(s, Command.DELETE, -1, "character")
    test.assert_eq(field:get_number(), nil)
    type_text(s, "-")
    test.assert_eq(field:get_text(), "-")
    test.assert_eq(field:get_number(), nil)
    type_text(s, "3")
    test.assert_eq(field:get_number(), -3)
    s.system.clipboard = "x"
    command(s, Command.SELECT_ALL)
    command(s, Command.PASTE)
    test.assert_eq(field:get_text(), "-3", "the paste was refused as a whole")
    s.system.clipboard = "42"
    command(s, Command.PASTE)
    test.assert_eq(field:get_number(), 42)
    field:set_number(7)
    test.assert_deep_eq(state(field), {
        "7",
        1,
        1,
        1
    })
    finish(s)
end)

test.case("a multivalue field starts empty, an edit marks a new value and a delete on the empty text toggles back", function()
    local s = setup()
    local field = s.field
    field:set_text("abc")
    field:set_multivalue(true)
    test.assert_eq(field:get_text(), "")
    test.assert_true(field:is_multivalue())
    test.assert_true(field:is_multivalue_default())
    s.form:focus(field)
    type_text(s, "x")
    test.assert_false(field:is_multivalue_default())
    command(s, Command.DELETE, -1, "character")
    test.assert_eq(field:get_text(), "")
    test.assert_false(field:is_multivalue_default(), "an emptied field holds a new, empty value")
    command(s, Command.DELETE, -1, "character")
    test.assert_true(field:is_multivalue_default(), "a delete on the empty text toggles back")
    command(s, Command.DELETE, -1, "character")
    test.assert_false(field:is_multivalue_default())
    finish(s)
end)

test.case("the pointer over the field asks for the I-beam where cursors are supported, and the arrow when it leaves", function()
    local s = setup()
    local previous = love.mouse

    ---@class TestMouse: love.mouse
    ---@field cursors string[] The system cursors set, in order
    ---@field made string[] The system cursors made, in order
    local mouse = {
        cursors = {},
        made = {}
    }

    ---@return boolean
    function mouse.isCursorSupported()
        return true
    end

    ---@param kind love.CursorType
    ---@return love.Cursor
    function mouse.getSystemCursor(kind)
        table.insert(mouse.made, kind)
        ---@class TestCursor: love.Cursor
        local cursor = {
            kind = kind
        }
        return cursor
    end

    ---@param cursor TestCursor
    function mouse.setCursor(cursor)
        table.insert(mouse.cursors, cursor.kind)
    end

    love.mouse = mouse
    ---@type boolean, any
    local ok, err = pcall(function()
        move(s, x_of(1), MID_Y)
        test.assert_true(s.field:is_hovered())
        move(s, 500, 500)
        move(s, x_of(1), MID_Y)
        test.assert_deep_eq(mouse.cursors, {
            "ibeam",
            "arrow",
            "ibeam"
        })
        test.assert_deep_eq(mouse.made, {
            "ibeam",
            "arrow"
        }, "each system cursor is fetched once")
    end)
    love.mouse = previous
    finish(s)
    if not ok then
        error(err, 0)
    end
end)

test.case("without cursor support nothing is asked of the mouse", function()
    local s = setup()
    move(s, x_of(1), MID_Y)
    test.assert_true(s.field:is_hovered())
    move(s, 500, 500)
    test.assert_false(s.field:is_hovered())
    finish(s)
end)

test.case("a hidden form ends the pointer registrations and a drag in progress; showing it again registers", function()
    local s = setup()
    local field = s.field
    field:set_text("hello")
    local manager = s.app.pointer_event_manager
    press(s, x_of(1), MID_Y, 1)
    test.assert_eq(manager:get_captor(1), field)

    s.form:hide()
    test.assert_eq(manager.pointer_down:get_handler(field), nil)
    test.assert_eq(manager.pointer_move:get_handler(field), nil)
    test.assert_eq(manager.pointer_up:get_handler(field), nil)
    test.assert_eq(manager:get_captor(1), nil)
    s.app.button_event_manager:dispatch_pointer_up(x_of(1), MID_Y, 1)

    s.form:show()
    test.assert_eq(manager.pointer_down:get_handler(field), TextInput.on_pointer_down)
    s.app:advance_time(1)
    click(s, x_of(3))
    test.assert_eq(field:get_caret(), 3)
    finish(s)
end)

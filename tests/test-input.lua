local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local ButtonEventManager = require("ui.button-event")
local FormScreen = require("ui.form-screen")
local Input = require("ui.input")
local TextEventManager = require("ui.text-event")
local TextInput = require("ui.text-input")

---@class TestInput: Control, Input
---@field name string
local TestInput = class("TestInput", Control, Input)

---@param parent Control|nil
---@param form_screen FormScreen
---@param name string
function TestInput:init(parent, form_screen, name)
    Control.init(self, parent, 10, 10)
    Input.init(self, form_screen)
    self.name = name
end

---@return AppMock
---@return FormScreen
local function setup()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    app_mock.root = Control()
    app_mock.button_event_manager = ButtonEventManager()
    return app_mock, FormScreen()
end

---@param form FormScreen
---@return string[]
local function input_names(form)
    local names = {}
    ---@diagnostic disable-next-line: invisible
    for _, input in ipairs(form._inputs) do
        ---@cast input TestInput
        table.insert(names, input.name)
    end
    return names
end

---What a case leaves, the inputs and their parents first, then the form, so
---nothing of it reaches the collector (docs/lifetimes.md, "Forms and inputs")
---@param form FormScreen
---@param ... Control
local function finish(form, ...)
    for i = 1, select("#", ...) do
        local obj = select(i, ...)
        if lifetime.alive(obj) then
            lifetime.destroy(obj)
        end
    end
    if lifetime.alive(form) then
        lifetime.destroy(form)
    end
end

test.suite("Input")

test.case("an input registers with its form and is linked to it by a hook", function()
    local _, form = setup()
    local a = TestInput(nil, form, "a")
    test.assert_deep_eq(input_names(form), {
        "a"
    })
    local hooks = lifetime.dependents(a)
    test.assert_eq(#hooks, 1)
    test.assert_eq(getmetatable(hooks[1]), "hook")
    test.assert_deep_eq(lifetime.dependents(form), hooks, "the same hook hangs on the form")
    finish(form, a)
end)

test.case("an input that dies first unlinks itself from the form and leaves the control tree", function()
    local _, form = setup()
    local parent = Control()
    local a = TestInput(parent, form, "a")
    local b = TestInput(parent, form, "b")
    form:focus(a)
    test.assert_true(a:is_focused())

    lifetime.destroy(a)
    test.assert_deep_eq(input_names(form), {
        "b"
    })
    test.assert_deep_eq(parent:get_children(), {
        b
    })
    test.assert_false(lifetime.alive(a))
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._focus, nil, "the focus index was cleared with the input")
    finish(form, parent)
end)

test.case("a destroyed focused text input loses the focus, so LÖVE text input is switched off", function()
    local app_mock, form = setup()
    mocks.ensure_love_graphics()
    mocks.ensure_love_mouse()
    local keyboard = mocks.make_keyboard()
    app_mock.text_event_manager = TextEventManager(keyboard)
    local parent = Control()
    local field = TextInput(parent, form, 100, 20, false, nil, nil)
    form:show()
    form:focus(field)
    test.assert_true(field:is_focused())
    test.assert_true(keyboard.text_input, "focusing a text field switches text input on")

    lifetime.destroy(field)
    test.assert_false(keyboard.text_input, "the field lost the focus while dying")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._focus, nil)
    test.assert_deep_eq(input_names(form), {})
    test.assert_deep_eq(parent:get_children(), {})
    finish(form, parent)
end)

test.case("a destroyed focused text input under the pointer lets go of it, then ends its text and pointer events", function()
    local app_mock, form = setup()
    mocks.ensure_love_graphics()
    mocks.ensure_love_mouse()
    app_mock.text_event_manager = TextEventManager(mocks.make_keyboard())
    local field = TextInput(form:get_control(), form, 100, 20, false, nil, nil)
    form:show()
    local pointer_manager, button_manager = app_mock.pointer_event_manager, app_mock.button_event_manager
    button_manager:dispatch_pointer_move(50, 10, 1)
    pointer_manager:dispatch_pointer_down(50, 10, 1)
    button_manager:dispatch_pointer_down(50, 10, 1)
    local button = field:get_button()
    test.assert_true(field:is_focused(), "the press focused the field")
    test.assert_true(button:is_hovered())
    test.assert_eq(pointer_manager:get_captor(1), field, "the press is held until its release")

    lifetime.destroy(field)
    test.assert_false(button:is_hovered(), "the pointer let go of the field")
    local text_appended = app_mock.text_event_manager.text_appended
    test.assert_eq(text_appended:get_handler(field), nil, "the view update of letting go did not leave the text events registered")
    test.assert_eq(pointer_manager.pointer_move:get_handler(field), nil)
    app_mock.text_event_manager:text_input("x")
    pointer_manager:dispatch_pointer_move(200, 200, nil)
    test.assert_eq(pointer_manager:get_captor(1), nil, "a captor that died let go")
    pointer_manager:dispatch_pointer_up(200, 200, 1)
    button_manager:dispatch_pointer_up(200, 200, 1)
    finish(form)
end)

test.case("removing an input below the focused one keeps the focus on the same input", function()
    local _, form = setup()
    local a = TestInput(nil, form, "a")
    local b = TestInput(nil, form, "b")
    local c = TestInput(nil, form, "c")
    form:focus(c)
    form:focus(b)
    test.assert_true(b:is_focused())
    lifetime.destroy(a)
    test.assert_deep_eq(input_names(form), {
        "b",
        "c"
    })
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._inputs[form._focus], b, "the index followed the list")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._inputs[form._prev_focus], c)
    test.assert_true(b:is_focused())
    finish(form, b, c)
end)

test.case("a focused input made read-only hands the focus to the next writable one, wrapping around", function()
    local _, form = setup()
    local a = TestInput(nil, form, "a")
    local b = TestInput(nil, form, "b")
    local c = TestInput(nil, form, "c")
    c:set_read_only(true)
    form:focus(a)

    a:set_read_only(true)
    test.assert_false(a:is_focused(), "the read-only input was told it lost the focus")
    test.assert_true(b:is_focused(), "and the next one that it has it")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._inputs[form._focus], b)

    a:set_read_only(false)
    test.assert_true(b:is_focused(), "an input made writable takes no focus")
    b:set_read_only(true)
    test.assert_false(b:is_focused())
    test.assert_true(a:is_focused(), "past the read-only one, around to the first")
    finish(form, a, b, c)
end)

test.case("the only writable input made read-only while focused leaves the form without a focus", function()
    local _, form = setup()
    local a = TestInput(nil, form, "a")
    local b = TestInput(nil, form, "b")
    b:set_read_only(true)
    form:focus(a)

    a:set_read_only(true)
    test.assert_false(a:is_focused())
    test.assert_false(b:is_focused())
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._focus, nil)
    form:on_key_pressed("tab")
    test.assert_false(a:is_focused(), "Tab finds nothing to focus")
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(form._focus, nil)

    a:set_read_only(false)
    form:on_key_pressed("tab")
    test.assert_true(a:is_focused(), "writable again, Tab reaches it")
    finish(form, a, b)
end)

test.case("a focused text input made read-only switches LÖVE text input off, the next text input on", function()
    local app_mock, form = setup()
    mocks.ensure_love_graphics()
    mocks.ensure_love_mouse()
    local keyboard = mocks.make_keyboard()
    app_mock.text_event_manager = TextEventManager(keyboard)
    local first = TextInput(form:get_control(), form, 100, 20, false, nil, nil)
    local second = TextInput(form:get_control(), form, 100, 20, false, nil, nil)
    second:set_position(0, 30)
    form:show()
    form:focus(first)

    second:set_read_only(true)
    first:set_read_only(true)
    test.assert_false(first:is_focused())
    test.assert_false(keyboard.text_input, "nothing left to type into")

    second:set_read_only(false)
    form:focus(second)
    first:set_read_only(false)
    second:set_read_only(true)
    test.assert_true(first:is_focused())
    test.assert_true(keyboard.text_input, "the next field has it on")
    finish(form)
end)

test.case("a form that dies first takes its list with it; the inputs stay alive and unhooked", function()
    local _, form = setup()
    local a = TestInput(nil, form, "a")
    local b = TestInput(nil, form, "b")
    local removed = 0
    form.remove_input = function(...)
        removed = removed + 1
        return FormScreen.remove_input(...)
    end

    lifetime.destroy(form)
    test.assert_eq(removed, 0, "the hooks found the form dying and did nothing")
    test.assert_true(lifetime.alive(a))
    test.assert_true(lifetime.alive(b))
    test.assert_deep_eq(lifetime.dependents(a), {}, "the hook died with the form")
    test.assert_deep_eq(lifetime.dependents(b), {})
    finish(form, a, b)
end)

test.case("a form and its inputs dying in one cascade: the form's body runs first, nothing is unlinked", function()
    local _, form = setup()
    local period = lifetime.token("period")
    form:attach_lifetime(period)
    local a = TestInput(nil, form, "a"):attach_lifetime(form)
    local b = TestInput(nil, form, "b"):attach_lifetime(form)
    local removed = 0
    form.remove_input = function(...)
        removed = removed + 1
        return FormScreen.remove_input(...)
    end

    lifetime.destroy(period)
    test.assert_eq(removed, 0)
    test.assert_false(lifetime.alive(form))
    test.assert_false(lifetime.alive(a))
    test.assert_false(lifetime.alive(b))
end)

test.case("a shown form that dies hides itself and its inputs end their registrations", function()
    local app_mock, form = setup()
    local a = TestInput(nil, form, "a")
    form:show()
    test.assert_eq(app_mock.keyboard_manager.key_pressed:get_handler(form), FormScreen.on_key_pressed)
    test.assert_true(form:is_showed())

    lifetime.destroy(form)
    test.assert_eq(app_mock.keyboard_manager.key_pressed:get_handler(form), nil)
    test.assert_deep_eq(app_mock.root:get_children(), {})
    test.assert_true(lifetime.alive(a), "the input is not the form's to destroy")
    finish(form, a)
end)

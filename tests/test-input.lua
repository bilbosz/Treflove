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
end)

test.case("a destroyed focused text input loses the focus, so LÖVE text input is switched off", function()
    local app_mock, form = setup()
    mocks.ensure_love_graphics()
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
end)

test.case("a destroyed focused text input under the pointer lets go of it, then ends its text events", function()
    local app_mock, form = setup()
    mocks.ensure_love_graphics()
    app_mock.text_event_manager = TextEventManager(mocks.make_keyboard())
    local field = TextInput(form:get_control(), form, 100, 20, false, nil, nil)
    form:show()
    local manager = app_mock.button_event_manager
    manager:dispatch_pointer_move(50, 10, 1)
    manager:dispatch_pointer_down(50, 10, 1)
    manager:dispatch_pointer_up(50, 10, 1)
    local button = field:get_button()
    test.assert_true(field:is_focused())
    test.assert_true(button:is_hovered())

    lifetime.destroy(field)
    test.assert_false(button:is_hovered(), "the pointer let go of the field")
    local text_appended = app_mock.text_event_manager.text_appended
    test.assert_eq(text_appended:get_handler(field), nil, "the view update of letting go did not leave the text events registered")
    app_mock.text_event_manager:text_input("x")
    manager:dispatch_pointer_move(200, 200, 1)
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
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local KeyboardManager = require("events.keyboard")
local TextBuffer = require("ui.text-buffer")
local TextEventManager = require("ui.text-event")

---@class TestTextField: Object
---@field buffer TextBuffer
---@field log string[] Entries are "edited:<text>", "removed_empty" or "entered"
local TestTextField = class("TestTextField")

function TestTextField:init()
    self.log = {}
    self.buffer = TextBuffer()
    self.buffer.edited:register(self, self.on_edit)
    self.buffer.removed_empty:register(self, self.on_remove_empty)
end

---@param manager TextEventManager
function TestTextField:register(manager)
    manager.text_appended:register(self, self.on_append_text)
    manager.characters_removed:register(self, self.on_remove_characters)
    manager.word_removed:register(self, self.on_remove_word)
    manager.entered:register(self, self.on_enter)
end

---@param text string
function TestTextField:on_edit(text)
    table.insert(self.log, "edited:" .. text)
end

function TestTextField:on_remove_empty()
    table.insert(self.log, "removed_empty")
end

function TestTextField:on_enter()
    table.insert(self.log, "entered")
end

---@param text string
function TestTextField:on_append_text(text)
    self.buffer:append_text(text)
end

---@param character_number number
function TestTextField:on_remove_characters(character_number)
    self.buffer:remove_characters(character_number)
end

function TestTextField:on_remove_word()
    self.buffer:remove_word()
end

test.suite("TextBuffer")

test.case("appending triggers edited with the whole text", function()
    local field = TestTextField()

    field.buffer:append_text("ab")
    field.buffer:append_text("c")

    test.assert_eq(field.buffer:get_text(), "abc")
    test.assert_deep_eq(field.log, {
        "edited:ab",
        "edited:abc"
    })
end)

test.case("removing characters counts UTF-8 characters, not bytes", function()
    local field = TestTextField()
    field.buffer:set_text("aé€")
    test.assert_eq(field.buffer:get_text_length(), 3)

    field.buffer:remove_characters(1)
    field.buffer:remove_characters(1)

    test.assert_eq(field.buffer:get_text(), "a")
    test.assert_deep_eq(field.log, {
        "edited:aé",
        "edited:a"
    })
end)

test.case("removing from an empty text triggers removed_empty only", function()
    local field = TestTextField()

    field.buffer:remove_characters(1)
    field.buffer:remove_word()

    test.assert_deep_eq(field.log, {
        "removed_empty",
        "removed_empty"
    })
end)

test.case("removing more characters than the text has does nothing", function()
    local field = TestTextField()
    field.buffer:set_text("ab")

    field.buffer:remove_characters(3)

    test.assert_eq(field.buffer:get_text(), "ab")
    test.assert_deep_eq(field.log, {})
end)

test.case("removing a word cuts at the last whitespace, including non-ASCII ones", function()
    local field = TestTextField()
    field.buffer:set_text("hello big\194\160world")

    for _ = 1, 4 do
        field.buffer:remove_word()
    end

    test.assert_deep_eq(field.log, {
        "edited:hello big",
        "edited:hello",
        "edited:",
        "removed_empty"
    })
end)

test.case("set_text replaces the text without triggering edited", function()
    local field = TestTextField()

    field.buffer:set_text("x")

    test.assert_eq(field.buffer:get_text(), "x")
    test.assert_deep_eq(field.log, {})
end)

---@class TestTextListener: Object
---@field log string[] One entry per event: "text:<text>", "<command> <direction> <step> <extend>" with the absent arguments left out, "characters_removed:<n>", "word_removed" or "entered"
local TestTextListener = class("TestTextListener")

---@param manager TextEventManager
function TestTextListener:init(manager)
    self.log = {}
    manager.text_appended:register(self, self.on_append_text)
    manager.commanded:register(self, self.on_command)
    manager.characters_removed:register(self, self.on_remove_characters)
    manager.word_removed:register(self, self.on_remove_word)
    manager.entered:register(self, self.on_enter)
end

---@param text string
function TestTextListener:on_append_text(text)
    table.insert(self.log, "text:" .. text)
end

---@param command TextCommand
---@param direction TextDirection|nil
---@param step TextStep|nil
---@param extend boolean|nil
function TestTextListener:on_command(command, direction, step, extend)
    ---@type string
    local entry = command
    if direction ~= nil then
        entry = entry .. " " .. tostring(direction)
    end
    if step ~= nil then
        entry = entry .. " " .. tostring(step)
    end
    if extend ~= nil then
        entry = entry .. " " .. tostring(extend)
    end
    table.insert(self.log, entry)
end

---@param character_number number
function TestTextListener:on_remove_characters(character_number)
    table.insert(self.log, "characters_removed:" .. character_number)
end

function TestTextListener:on_remove_word()
    table.insert(self.log, "word_removed")
end

function TestTextListener:on_enter()
    table.insert(self.log, "entered")
end

---@return AppMock, TextEventManager, TestTextListener With text input on
local function setup_commands()
    local app_mock = mocks.install_app()
    local manager = app_mock.text_event_manager
    manager:set_text_input(true)
    return app_mock, manager, TestTextListener(manager)
end

---@param app_mock AppMock
---@param modifiers love.KeyConstant[] Held through the keyboard manager while `key` is pressed
---@param key love.KeyConstant
local function press_with(app_mock, modifiers, key)
    for _, modifier in ipairs(modifiers) do
        app_mock.keyboard_manager:dispatch_key_pressed(modifier)
    end
    app_mock.text_event_manager:key_pressed(key)
    for _, modifier in ipairs(modifiers) do
        app_mock.keyboard_manager:dispatch_key_released(modifier)
    end
end

test.suite("TextEventManager")

test.case("init turns text input off and key repeat on", function()
    local keyboard = mocks.make_keyboard()
    keyboard.text_input = true

    local manager = TextEventManager(keyboard, mocks.make_system())

    test.assert_false(manager:is_text_input())
    test.assert_true(keyboard.key_repeat)
    manager:set_text_input(true)
    test.assert_true(manager:is_text_input())
    test.assert_true(keyboard.text_input)
end)

test.case("typed text goes to the registered listeners", function()
    local _, manager, listener = setup_commands()

    manager:text_input("h")
    manager:text_input("é")

    test.assert_deep_eq(listener.log, {
        "text:h",
        "text:é"
    })
end)

test.case("text typed while ctrl is held is dropped", function()
    local app_mock, manager, listener = setup_commands()

    app_mock.keyboard_manager:dispatch_key_pressed("rctrl")
    manager:text_input("a")
    app_mock.keyboard_manager:dispatch_key_released("rctrl")
    app_mock.keyboard_manager:dispatch_key_pressed("lshift")
    manager:text_input("B")

    test.assert_deep_eq(listener.log, {
        "text:B"
    })
end)

test.case("unregistered listeners stop receiving", function()
    local _, manager, listener = setup_commands()
    manager.text_appended:unregister(listener)
    manager.commanded:unregister(listener)

    manager:text_input("x")
    manager:key_pressed("left")

    test.assert_deep_eq(listener.log, {})
end)

test.case("keys are translated only while text input is active", function()
    local app_mock, manager, listener = setup_commands()
    manager:set_text_input(false)

    for _, key in ipairs({
        "left",
        "home",
        "backspace",
        "return"
    }) do
        manager:key_pressed(key)
    end
    press_with(app_mock, {
        "lctrl"
    }, "a")

    test.assert_deep_eq(listener.log, {})
end)

test.case("the arrows move by character, by word with ctrl, extending with shift", function()
    local app_mock, _, listener = setup_commands()

    press_with(app_mock, {}, "left")
    press_with(app_mock, {}, "right")
    press_with(app_mock, {
        "lctrl"
    }, "left")
    press_with(app_mock, {
        "rshift"
    }, "right")
    press_with(app_mock, {
        "rctrl",
        "lshift"
    }, "right")

    test.assert_deep_eq(listener.log, {
        "move -1 character false",
        "move 1 character false",
        "move -1 word false",
        "move 1 character true",
        "move 1 word true"
    })
end)

test.case("home and end move by line whatever ctrl says, extending with shift", function()
    local app_mock, _, listener = setup_commands()

    press_with(app_mock, {}, "home")
    press_with(app_mock, {
        "lctrl"
    }, "end")
    press_with(app_mock, {
        "lshift"
    }, "end")

    test.assert_deep_eq(listener.log, {
        "move -1 line false",
        "move 1 line false",
        "move 1 line true"
    })
end)

test.case("backspace and delete delete by character, by word with ctrl; the deprecated events follow a backward delete", function()
    local app_mock, _, listener = setup_commands()

    press_with(app_mock, {}, "backspace")
    press_with(app_mock, {
        "lctrl"
    }, "backspace")
    press_with(app_mock, {}, "delete")
    press_with(app_mock, {
        "rctrl"
    }, "delete")

    test.assert_deep_eq(listener.log, {
        "delete -1 character",
        "characters_removed:1",
        "delete -1 word",
        "word_removed",
        "delete 1 character",
        "delete 1 word"
    })
end)

test.case("return and the keypad's enter enter; the deprecated event follows", function()
    local app_mock, _, listener = setup_commands()

    press_with(app_mock, {}, "return")
    press_with(app_mock, {
        "lshift"
    }, "kpenter")

    test.assert_deep_eq(listener.log, {
        "enter",
        "entered",
        "enter",
        "entered"
    })
end)

test.case("ctrl with a, c, x, v, z and y selects, copies, cuts, pastes, undoes and redoes; shift turns undo into redo", function()
    local app_mock, _, listener = setup_commands()

    for _, key in ipairs({
        "a",
        "c",
        "x",
        "v",
        "z",
        "y"
    }) do
        press_with(app_mock, {
            "lctrl"
        }, key)
    end
    press_with(app_mock, {
        "rctrl",
        "rshift"
    }, "z")

    test.assert_deep_eq(listener.log, {
        "select_all",
        "copy",
        "cut",
        "paste",
        "undo",
        "redo",
        "redo"
    })
end)

test.case("on macOS the command keys are ctrl", function()
    local app_mock, _, listener = setup_commands()
    app_mock.system.os = "OS X"

    press_with(app_mock, {
        KeyboardManager.LEFT_COMMAND_KEY
    }, "c")
    press_with(app_mock, {
        KeyboardManager.RIGHT_COMMAND_KEY
    }, "left")

    test.assert_deep_eq(listener.log, {
        "copy",
        "move -1 word false"
    })
end)

test.case("AltGr, left ctrl with right alt as Windows reports it, types its letters and commands nothing", function()
    local app_mock, manager, listener = setup_commands()
    local keyboard_manager = app_mock.keyboard_manager
    keyboard_manager:dispatch_key_pressed("lctrl")
    keyboard_manager:dispatch_key_pressed("ralt")

    for _, key in ipairs({
        "a",
        "c",
        "x",
        "v",
        "z",
        "y"
    }) do
        manager:key_pressed(key)
    end
    manager:text_input("ą")

    test.assert_deep_eq(listener.log, {
        "text:ą"
    })
end)

test.case("the letters without ctrl and any other key command nothing", function()
    local app_mock, manager, listener = setup_commands()

    for _, key in ipairs({
        "a",
        "c",
        "v",
        "z",
        "y",
        "up",
        "down",
        "tab",
        "escape",
        "lctrl",
        "lshift"
    }) do
        manager:key_pressed(key)
    end
    press_with(app_mock, {
        "lctrl"
    }, "q")
    press_with(app_mock, {
        "lshift"
    }, "a")

    test.assert_deep_eq(listener.log, {})
end)

test.case("the clipboard is the system's", function()
    local app_mock, manager = setup_commands()

    manager:set_clipboard("copied")

    test.assert_eq(app_mock.system.clipboard, "copied")
    test.assert_eq(manager:get_clipboard(), "copied")
end)

test.case("the clipboard is read as one line: carriage returns dropped, line feeds turned into spaces", function()
    local app_mock, manager = setup_commands()

    app_mock.system.clipboard = "one\r\ntwo\nthree\r"

    test.assert_eq(manager:get_clipboard(), "one two three")
end)

test.case("a clipboard that is not UTF-8 reads empty", function()
    local app_mock, manager = setup_commands()
    -- The pure-Lua shim of plain LuaJIT does not validate: only LÖVE's utf8 rejects the invalid text
    local utf8_validates = require("utf8").len("\255") == nil

    app_mock.system.clipboard = "ab\255cd"
    if utf8_validates then
        test.assert_eq(manager:get_clipboard(), "")
    end
    app_mock.system.clipboard = "żółw"
    test.assert_eq(manager:get_clipboard(), "żółw")
end)

test.case("without a backend, love.system is read at the call", function()
    local previous = love.system
    local system = mocks.make_system()
    local manager = TextEventManager(mocks.make_keyboard())
    love.system = system

    manager:set_clipboard("x")
    local clipboard = manager:get_clipboard()
    love.system = previous

    test.assert_eq(system.clipboard, "x")
    test.assert_eq(clipboard, "x")
end)

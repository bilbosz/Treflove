local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local TextBuffer = require("ui.text-buffer")
local TextEventManager = require("ui.text-event")

-- Owns a TextBuffer the way TextInput does: buffer events are logged, manager
-- events are applied to the buffer by methods registered on the manager.
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

test.suite("TextEventManager")

test.case("init turns text input off and key repeat on", function()
    local keyboard = mocks.make_keyboard()
    keyboard.text_input = true

    local manager = TextEventManager(keyboard --[[@as love.keyboard]] )

    test.assert_false(manager:is_text_input())
    test.assert_true(keyboard.key_repeat)
    manager:set_text_input(true)
    test.assert_true(manager:is_text_input())
    test.assert_true(keyboard.text_input)
end)

test.case("text input is appended to registered fields", function()
    local manager = TextEventManager(mocks.make_keyboard() --[[@as love.keyboard]] )
    local field, other = TestTextField(), TestTextField()
    field:register(manager)

    manager:text_input("h")
    manager:text_input("i")

    test.assert_eq(field.buffer:get_text(), "hi")
    test.assert_eq(other.buffer:get_text(), "")
end)

test.case("editing keys are routed only while text input is active", function()
    local keyboard = mocks.make_keyboard()
    local manager = TextEventManager(keyboard --[[@as love.keyboard]] )
    local field = TestTextField()
    field:register(manager)
    field.buffer:set_text("one two")

    manager:key_pressed("backspace")
    manager:key_pressed("return")
    test.assert_deep_eq(field.log, {})

    manager:set_text_input(true)
    manager:key_pressed("backspace")
    keyboard.down["rctrl"] = true
    manager:key_pressed("backspace")
    keyboard.down["rctrl"] = nil
    manager:key_pressed("a")
    manager:key_pressed("return")

    test.assert_deep_eq(field.log, {
        "edited:one tw",
        "edited:one",
        "entered"
    })
end)

test.case("unregistered fields stop receiving", function()
    local manager = TextEventManager(mocks.make_keyboard() --[[@as love.keyboard]] )
    local field = TestTextField()
    field:register(manager)
    manager.text_appended:unregister(field)

    manager:text_input("x")

    test.assert_eq(field.buffer:get_text(), "")
end)

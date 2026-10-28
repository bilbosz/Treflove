local test = require("tests.lib.test")
local TextBuffer = require("ui.text-buffer")

---@class TestBufferLog: Object
---@field buffer TextBuffer
---@field log string[] Entries are "edited:<text>", "moved" or "removed_empty"
local TestBufferLog = class("TestBufferLog")

function TestBufferLog:init()
    self.log = {}
    self.buffer = TextBuffer()
    self.buffer.edited:register(self, self.on_edit)
    self.buffer.moved:register(self, self.on_move)
    self.buffer.removed_empty:register(self, self.on_remove_empty)
end

---@param text string
function TestBufferLog:on_edit(text)
    table.insert(self.log, "edited:" .. text)
end

function TestBufferLog:on_move()
    table.insert(self.log, "moved")
end

function TestBufferLog:on_remove_empty()
    table.insert(self.log, "removed_empty")
end

---@param buffer TextBuffer
---@return {[1]: string, [2]: integer, [3]: integer, [4]: integer} The text, the caret, the selection's start and end
local function state(buffer)
    local start, finish = buffer:get_selection()
    return {
        buffer:get_text(),
        buffer:get_caret(),
        start,
        finish
    }
end

test.suite("TextBuffer")

test.case("set_text puts the caret at the end with no selection and no event; the length counts codepoints", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    test.assert_deep_eq(state(buffer), {
        "",
        0,
        0,
        0
    })

    buffer:set_text("aé€")

    test.assert_eq(buffer:get_text_length(), 3)
    test.assert_deep_eq(state(buffer), {
        "aé€",
        3,
        3,
        3
    })
    test.assert_false(buffer:has_selection())
    test.assert_deep_eq(field.log, {})
end)

test.case("insert goes in at the caret and triggers edited with the whole text", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    buffer:insert("ac")
    buffer:set_caret(1)
    buffer:insert("é")

    test.assert_deep_eq(state(buffer), {
        "aéc",
        2,
        2,
        2
    })
    test.assert_deep_eq(field.log, {
        "edited:ac",
        "moved",
        "edited:aéc"
    })
end)

test.case("set_caret clamps, moves the anchor along unless extended, and triggers moved only on a change", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    buffer:set_text("hello")

    buffer:set_caret(9)
    test.assert_deep_eq(state(buffer), {
        "hello",
        5,
        5,
        5
    })
    test.assert_deep_eq(field.log, {}, "the caret was at the end already")
    buffer:set_caret(-3)
    buffer:set_caret(3, true)
    test.assert_deep_eq(state(buffer), {
        "hello",
        3,
        0,
        3
    })
    test.assert_true(buffer:has_selection())
    test.assert_eq(buffer:get_selected_text(), "hel")
    buffer:set_caret(1, true)
    test.assert_eq(buffer:get_selected_text(), "h")
    buffer:set_caret(4)
    test.assert_false(buffer:has_selection())
    test.assert_deep_eq(field.log, {
        "moved",
        "moved",
        "moved",
        "moved"
    })
end)

test.case("select_all, select_range and the selection's order", function()
    local buffer = TextBuffer()
    buffer:set_text("hello")
    buffer:select_all()
    test.assert_deep_eq(state(buffer), {
        "hello",
        5,
        0,
        5
    })

    buffer:select_range(4, 1)
    test.assert_deep_eq(state(buffer), {
        "hello",
        1,
        1,
        4
    }, "the anchor at the start, the caret at the finish")
    test.assert_eq(buffer:get_selected_text(), "ell")
    buffer:select_range(-2, 20)
    test.assert_eq(buffer:get_selected_text(), "hello")
end)

test.case("a move by character collapses a selection to its near end; by word or line it collapses and goes on", function()
    local buffer = TextBuffer()
    buffer:set_text("one two three")
    buffer:select_range(4, 7)
    buffer:move(-1, "character")
    test.assert_deep_eq(state(buffer), {
        "one two three",
        4,
        4,
        4
    })
    buffer:select_range(4, 7)
    buffer:move(1, "character")
    test.assert_eq(buffer:get_caret(), 7)

    buffer:select_range(5, 6)
    buffer:move(-1, "word")
    test.assert_eq(buffer:get_caret(), 4, "from the selection's start to the start of 'two'")
    buffer:select_range(5, 6)
    buffer:move(1, "word")
    test.assert_eq(buffer:get_caret(), 7, "from the selection's end to the end of 'two'")
    buffer:select_range(5, 6)
    buffer:move(1, "line")
    test.assert_eq(buffer:get_caret(), 13)
    buffer:move(-1, "line")
    test.assert_eq(buffer:get_caret(), 0)
    test.assert_false(buffer:has_selection())
end)

test.case("a move by character steps one codepoint and stops at the ends; extended, it grows the selection", function()
    local buffer = TextBuffer()
    buffer:set_text("aé€")
    buffer:move(-1, "character")
    buffer:move(-1, "character")
    test.assert_eq(buffer:get_caret(), 1)
    buffer:move(-1, "character")
    buffer:move(-1, "character")
    test.assert_eq(buffer:get_caret(), 0)
    buffer:move(1, "character", true)
    buffer:move(1, "character", true)
    test.assert_eq(buffer:get_selected_text(), "aé")
    buffer:move(1, "character", true)
    buffer:move(1, "character", true)
    test.assert_deep_eq(state(buffer), {
        "aé€",
        3,
        0,
        3
    })
end)

test.case("a word move skips whitespace, non-ASCII too, then the word, in both directions", function()
    local buffer = TextBuffer()
    buffer:set_text("  hello big\194\160world  ")
    buffer:move(-1, "word")
    test.assert_eq(buffer:get_caret(), 12, "the start of 'world'")
    buffer:move(-1, "word")
    test.assert_eq(buffer:get_caret(), 8, "the start of 'big'")
    buffer:move(-1, "word")
    test.assert_eq(buffer:get_caret(), 2)
    buffer:move(-1, "word")
    test.assert_eq(buffer:get_caret(), 0)

    buffer:move(1, "word")
    test.assert_eq(buffer:get_caret(), 7, "the end of 'hello'")
    buffer:move(1, "word")
    test.assert_eq(buffer:get_caret(), 11)
    buffer:move(1, "word", true)
    test.assert_eq(buffer:get_selected_text(), "\194\160world")
    buffer:move(1, "word", true)
    test.assert_eq(buffer:get_caret(), 19)
end)

test.case("a line move goes to the ends", function()
    local buffer = TextBuffer()
    buffer:set_text("hello")
    buffer:set_caret(2)
    buffer:move(1, "line")
    test.assert_eq(buffer:get_caret(), 5)
    buffer:move(-1, "line", true)
    test.assert_deep_eq(state(buffer), {
        "hello",
        0,
        0,
        5
    })
end)

test.case("delete removes one codepoint on either side of the caret and nothing at the ends", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    buffer:set_text("aé€b")
    buffer:set_caret(2)

    buffer:delete(-1, "character")
    buffer:delete(1, "character")
    test.assert_deep_eq(state(buffer), {
        "ab",
        1,
        1,
        1
    })
    buffer:set_caret(0)
    buffer:delete(-1, "character")
    buffer:set_caret(2)
    buffer:delete(1, "character")
    test.assert_eq(buffer:get_text(), "ab")
    test.assert_deep_eq(field.log, {
        "moved",
        "edited:a€b",
        "edited:ab",
        "moved",
        "moved"
    }, "nothing fired at the ends")
end)

test.case("delete on an empty text triggers removed_empty only", function()
    local field = TestBufferLog()
    field.buffer:delete(-1, "character")
    field.buffer:delete(1, "word")
    test.assert_deep_eq(field.log, {
        "removed_empty",
        "removed_empty"
    })
end)

test.case("delete with a selection removes the selection whatever the step", function()
    local buffer = TextBuffer()
    buffer:set_text("one two three")
    buffer:select_range(4, 7)
    buffer:delete(1, "word")
    test.assert_deep_eq(state(buffer), {
        "one  three",
        4,
        4,
        4
    })
    buffer:select_range(5, 10)
    buffer:delete(-1, "character")
    test.assert_eq(buffer:get_text(), "one  ")
end)

test.case("a word delete removes what a word move would cross", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    buffer:set_text("hello big\194\160world")
    buffer:delete(-1, "word")
    buffer:delete(-1, "word")
    test.assert_eq(buffer:get_text(), "hello ")
    buffer:set_caret(0)
    buffer:delete(1, "word")
    test.assert_eq(buffer:get_text(), " ")
    buffer:delete(1, "word")
    test.assert_eq(buffer:get_text(), "")
    buffer:delete(1, "word")
    test.assert_deep_eq(field.log, {
        "edited:hello big\194\160",
        "edited:hello ",
        "moved",
        "edited: ",
        "edited:",
        "removed_empty"
    })
end)

test.case("insert replaces the selection and leaves the caret after the text", function()
    local buffer = TextBuffer()
    buffer:set_text("one two three")
    buffer:select_range(8, 4)
    buffer:insert("2 ")
    test.assert_deep_eq(state(buffer), {
        "one 2 three",
        6,
        6,
        6
    })
end)

test.case("undo and redo restore the text, the caret and the anchor, and trigger edited", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    buffer:set_text("abc")
    buffer:select_range(1, 2)
    buffer:insert("xy")
    test.assert_eq(buffer:get_text(), "axyc")

    buffer:undo()
    test.assert_deep_eq(state(buffer), {
        "abc",
        2,
        1,
        2
    })
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc", "nothing older to restore")
    buffer:redo()
    test.assert_deep_eq(state(buffer), {
        "axyc",
        3,
        3,
        3
    })
    buffer:redo()
    test.assert_deep_eq(field.log, {
        "moved",
        "edited:axyc",
        "edited:abc",
        "edited:axyc"
    })
end)

test.case("single non-whitespace inserts coalesce into one undo step; a space, a move or a delete ends the run", function()
    local buffer = TextBuffer()
    buffer:insert("a")
    buffer:insert("b")
    buffer:insert("c")
    buffer:insert(" ")
    buffer:insert("d")
    buffer:insert("e")
    buffer:set_caret(6)
    buffer:insert("f")
    buffer:insert("g")
    buffer:delete(-1, "character")
    buffer:insert("h")
    buffer:insert("ij")
    buffer:insert("k")
    test.assert_eq(buffer:get_text(), "abc defhijk")

    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc defhij", "a single codepoint after a longer insert is a step of its own")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc defh")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc def", "the insert after the delete")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc defg", "the delete")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc de", "the inserts after the move")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc ", "the inserts after the space")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "abc", "the space")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "", "the first run")
    test.assert_eq(buffer:get_caret(), 0)
end)

test.case("an edit after an undo clears the redo stack; set_text clears the history", function()
    local buffer = TextBuffer()
    buffer:insert("a")
    buffer:insert(" ")
    buffer:undo()
    buffer:insert("b")
    buffer:redo()
    test.assert_eq(buffer:get_text(), "ab")

    buffer:set_text("x")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "x")
end)

test.case("the filter is asked with the whole candidate and a refusal leaves the buffer as it is, silently", function()
    local field = TestBufferLog()
    local buffer = field.buffer
    ---@type string[]
    local asked = {}
    buffer:set_filter(function(candidate)
        table.insert(asked, candidate)
        return not string.find(candidate, "x")
    end)
    buffer:insert("ab")
    buffer:insert("x")
    buffer:set_caret(1)
    buffer:insert("c")
    test.assert_eq(buffer:get_text(), "acb")
    test.assert_deep_eq(asked, {
        "ab",
        "abx",
        "acb"
    })

    buffer:set_filter(function(candidate)
        return candidate ~= "ab"
    end)
    buffer:delete(-1, "character")
    test.assert_eq(buffer:get_text(), "acb", "the delete would make 'ab'")
    buffer:undo()
    test.assert_eq(buffer:get_text(), "acb", "the undo would restore 'ab'")
    buffer:set_filter(nil)
    buffer:undo()
    test.assert_eq(buffer:get_text(), "ab")
    test.assert_deep_eq(field.log, {
        "edited:ab",
        "moved",
        "edited:acb",
        "edited:ab"
    })
end)

test.case("get_word_at finds the word around an index, whitespace being a word of its own", function()
    local buffer = TextBuffer()
    buffer:set_text("one  two")
    test.assert_deep_eq({
        buffer:get_word_at(0)
    }, {
        0,
        3
    })
    test.assert_deep_eq({
        buffer:get_word_at(2)
    }, {
        0,
        3
    })
    test.assert_deep_eq({
        buffer:get_word_at(3)
    }, {
        3,
        5
    }, "the whitespace run")
    test.assert_deep_eq({
        buffer:get_word_at(8)
    }, {
        5,
        8
    }, "the end belongs to the last word")
    test.assert_deep_eq({
        buffer:get_word_at(20)
    }, {
        5,
        8
    })
    buffer:set_text("")
    test.assert_deep_eq({
        buffer:get_word_at(0)
    }, {
        0,
        0
    })
end)

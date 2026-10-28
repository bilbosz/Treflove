local Event = require("events.event")
local utf8 = require("utf8")

---@class TextSnapshot
---@field text string
---@field caret integer
---@field anchor integer

---@alias TextFilter fun(candidate: string): boolean|nil

---@class TextBuffer: Object
---@field public edited Event Triggered with (text) after the text changed by an edit, an undo or a redo
---@field public moved Event Triggered when the caret or the anchor changed and the text did not
---@field public removed_empty Event Triggered by a delete on an empty text
---@field private _text string
---@field private _caret integer
---@field private _anchor integer
---@field private _filter TextFilter|nil
---@field private _undo TextSnapshot[]
---@field private _redo TextSnapshot[]
---@field private _coalescing boolean The last edit was an insert of one non-whitespace codepoint and nothing happened since
local TextBuffer = class("TextBuffer")

---@type number[]
local WHITESPACE_CODES = {
    0x9,
    0xA,
    0xB,
    0xC,
    0xD,
    0x20,
    0x85,
    0xA0,
    0x1680,
    0x2000,
    0x2001
}

---@param code integer
---@return boolean
local function _is_whitespace(code)
    for _, wcode in ipairs(WHITESPACE_CODES) do
        if code == wcode then
            return true
        end
    end
    return false
end

---@param character string One codepoint
---@return integer
local function _code_of(character)
    local next_code = utf8.codes(character)
    local _, code = next_code(character, 0)
    return assert(code, "not a character: " .. character)
end

function TextBuffer:init()
    self.edited = Event()
    self.moved = Event()
    self.removed_empty = Event()
    self._text = ""
    self._caret = 0
    self._anchor = 0
    self._filter = nil
    self._undo = {}
    self._redo = {}
    self._coalescing = false
end

---@private
---@param index integer A codepoint count, from 0 to the length
---@return integer The byte position the codepoint after `index` starts at; one past the end at the length
function TextBuffer:_byte_offset(index)
    return assert(utf8.offset(self._text, index + 1))
end

---@private
---@param start integer
---@param finish integer
---@return string The codepoints from `start` to `finish`, the latter excluded
function TextBuffer:_sub(start, finish)
    return string.sub(self._text, self:_byte_offset(start), self:_byte_offset(finish) - 1)
end

---@private
---@param index integer From 0 to the length minus one
---@return integer The codepoint after `index`
function TextBuffer:_code_at(index)
    return _code_of(self:_sub(index, index + 1))
end

---@private
---@param index integer
---@return integer
function TextBuffer:_clamp(index)
    return math.max(0, math.min(self:get_text_length(), index))
end

---@return string
function TextBuffer:get_text()
    return self._text
end

---@param text string Replaces the text: the caret at the end, no selection, the history cleared, no event
function TextBuffer:set_text(text)
    assert_type(text, "string")
    self._text = text
    self._caret = self:get_text_length()
    self._anchor = self._caret
    self._undo = {}
    self._redo = {}
    self._coalescing = false
end

---@return integer
function TextBuffer:get_text_length()
    local length = utf8.len(self._text)
    assert(length, "the text is not UTF-8")
    return length
end

---@return integer
function TextBuffer:get_caret()
    return self._caret
end

---@return integer, integer The selection's start and end; equal when there is none
function TextBuffer:get_selection()
    return math.min(self._anchor, self._caret), math.max(self._anchor, self._caret)
end

---@return boolean
function TextBuffer:has_selection()
    return self._anchor ~= self._caret
end

---@return string
function TextBuffer:get_selected_text()
    return self:_sub(self:get_selection())
end

---@private
---@param caret integer Already within the text
---@param anchor integer Already within the text
function TextBuffer:_place(caret, anchor)
    self._coalescing = false
    if caret == self._caret and anchor == self._anchor then
        return
    end
    self._caret, self._anchor = caret, anchor
    self.moved:trigger()
end

---@param index integer Clamped to [0, length]
---@param extend boolean|nil Keep the anchor (extend the selection); otherwise the anchor follows the caret
function TextBuffer:set_caret(index, extend)
    local caret = self:_clamp(index)
    self:_place(caret, extend and self._anchor or caret)
end

function TextBuffer:select_all()
    self:_place(self:get_text_length(), 0)
end

---@param start integer The anchor goes here
---@param finish integer The caret goes here
function TextBuffer:select_range(start, finish)
    self:_place(self:_clamp(finish), self:_clamp(start))
end

---@private
---@param index integer
---@return integer The index a word move backward from `index` lands on: over whitespace, then over a word
function TextBuffer:_word_start_before(index)
    local i = index
    while i > 0 and _is_whitespace(self:_code_at(i - 1)) do
        i = i - 1
    end
    while i > 0 and not _is_whitespace(self:_code_at(i - 1)) do
        i = i - 1
    end
    return i
end

---@private
---@param index integer
---@return integer The index a word move forward from `index` lands on: over whitespace, then over a word
function TextBuffer:_word_end_after(index)
    local length = self:get_text_length()
    local i = index
    while i < length and _is_whitespace(self:_code_at(i)) do
        i = i + 1
    end
    while i < length and not _is_whitespace(self:_code_at(i)) do
        i = i + 1
    end
    return i
end

---@private
---@param from integer
---@param direction TextDirection
---@param step TextStep
---@return integer Where a move by `step` from `from` lands
function TextBuffer:_target(from, direction, step)
    if step == "line" then
        return direction < 0 and 0 or self:get_text_length()
    elseif step == "word" then
        return direction < 0 and self:_word_start_before(from) or self:_word_end_after(from)
    end
    return self:_clamp(from + direction)
end

---@param direction TextDirection
---@param step TextStep
---@param extend boolean|nil
function TextBuffer:move(direction, step, extend)
    local from = self._caret
    if self:has_selection() and not extend then
        local start, finish = self:get_selection()
        from = direction < 0 and start or finish
        if step == "character" then
            self:set_caret(from)
            return
        end
    end
    self:set_caret(self:_target(from, direction, step), extend)
end

---@param filter TextFilter|nil Asked before every insert, delete, undo and redo with the text it would produce; a false answer leaves the buffer as it is, without an event. Nil removes the filter
function TextBuffer:set_filter(filter)
    self._filter = filter
end

---@private
---@param candidate string
---@return boolean
function TextBuffer:_accepts(candidate)
    local filter = self._filter
    return filter == nil or toboolean(filter(candidate))
end

---@private
---@return TextSnapshot
function TextBuffer:_snapshot()
    return {
        text = self._text,
        caret = self._caret,
        anchor = self._anchor
    }
end

---@private
---@param snapshot TextSnapshot
function TextBuffer:_restore(snapshot)
    self._text, self._caret, self._anchor = snapshot.text, snapshot.caret, snapshot.anchor
end

---@private
---@param start integer
---@param finish integer
---@param text string What replaces the span from `start` to `finish`
---@param coalesce boolean Whether this edit joins the previous one's undo step
---@return boolean Whether the filter accepted the edit
function TextBuffer:_replace(start, finish, text, coalesce)
    local candidate = self:_sub(0, start) .. text .. self:_sub(finish, self:get_text_length())
    if not self:_accepts(candidate) then
        return false
    end
    if not (coalesce and self._coalescing) then
        table.insert(self._undo, self:_snapshot())
    end
    self._redo = {}
    self._text = candidate
    local length = utf8.len(text)
    assert(length, "the text is not UTF-8")
    self._caret = start + length
    self._anchor = self._caret
    self._coalescing = coalesce
    self.edited:trigger(self._text)
    return true
end

---@param text string Replaces the selection, or goes in at the caret; the caret ends after it
function TextBuffer:insert(text)
    assert_type(text, "string")
    local start, finish = self:get_selection()
    local coalesce = utf8.len(text) == 1 and not _is_whitespace(_code_of(text))
    self:_replace(start, finish, text, coalesce)
end

---@param direction TextDirection
---@param step TextStep With a selection, the selection goes whatever the step
function TextBuffer:delete(direction, step)
    if self:has_selection() then
        local start, finish = self:get_selection()
        self:_replace(start, finish, "", false)
        return
    end
    if self._text == "" then
        self.removed_empty:trigger()
        return
    end
    local target = self:_target(self._caret, direction, step)
    if target == self._caret then
        return
    end
    self:_replace(math.min(target, self._caret), math.max(target, self._caret), "", false)
end

---@private
---@param from TextSnapshot[] The stack the state comes from
---@param to TextSnapshot[] The stack the current state goes on
function TextBuffer:_travel(from, to)
    local snapshot = from[#from]
    if not snapshot or not self:_accepts(snapshot.text) then
        return
    end
    table.remove(from)
    table.insert(to, self:_snapshot())
    self:_restore(snapshot)
    self._coalescing = false
    self.edited:trigger(self._text)
end

function TextBuffer:undo()
    self:_travel(self._undo, self._redo)
end

function TextBuffer:redo()
    self:_travel(self._redo, self._undo)
end

---@param index integer Clamped to [0, length]
---@return integer, integer The start and end of the word around the index (whitespace is a word of its own)
function TextBuffer:get_word_at(index)
    local length = self:get_text_length()
    if length == 0 then
        return 0, 0
    end
    local i = self:_clamp(index)
    local probe = i < length and i or length - 1
    local whitespace = _is_whitespace(self:_code_at(probe))
    local start, finish = probe, probe + 1
    while start > 0 and _is_whitespace(self:_code_at(start - 1)) == whitespace do
        start = start - 1
    end
    while finish < length and _is_whitespace(self:_code_at(finish)) == whitespace do
        finish = finish + 1
    end
    return start, finish
end

return TextBuffer

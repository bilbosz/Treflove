local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local fonts = require("graphics.fonts")
local lifetime = require("lifetime")

---@class WatchOverlay: Control
---@field private _background Rectangle
---@field private _lines Text[]
local WatchOverlay = class("WatchOverlay", Control)

-- At a small pixel size the glyph advances round up to whole pixels, so the
-- drawn text is wider than its layout in model units
local TEXT_WIDTH_SLACK = 1.1

---@param byte integer
---@return integer length The length of the UTF-8 sequence it leads, 0 for a byte that leads none
local function _sequence_length(byte)
    if byte < 0x80 then
        return 1
    elseif byte >= 0xC2 and byte <= 0xDF then
        return 2
    elseif byte >= 0xE0 and byte <= 0xEF then
        return 3
    elseif byte >= 0xF0 and byte <= 0xF4 then
        return 4
    end
    return 0
end

---@param line string
---@return string displayable One line of UTF-8, a byte out of a sequence as `?`, at most `Consts.WATCH_OVERLAY_MAX_LINE_LENGTH` characters
local function _displayable(line)
    line = string.gsub(line, "%s+", " ")
    ---@type string[]
    local characters = {}
    local i = 1
    while i <= #line do
        local length = _sequence_length(string.byte(line, i))
        local sequence = string.sub(line, i, i + length - 1)
        if length == 0 or #sequence < length or string.find(sequence, "[^\128-\191]", 2) then
            sequence, length = "?", 1
        end
        table.insert(characters, sequence)
        i = i + length
    end
    local limit = Consts.WATCH_OVERLAY_MAX_LINE_LENGTH
    if #characters > limit then
        return table.concat(characters, "", 1, limit) .. "..."
    end
    return table.concat(characters)
end

function WatchOverlay:init()
    Control.init(self, nil, 0, 0)
    self._background = Rectangle(self, 0, 0, Consts.WATCH_OVERLAY_BACKGROUND_COLOR)
    self._lines = {}
    self:set_visible(false)
    self:_rescale()
    if app.resize_manager then
        app.resize_manager.resized:register(self, self.on_resize)
    end
    if app.keyboard_manager then
        app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
    end
end

---@param lines string[] One per watch, `name: value`
function WatchOverlay:set_lines(lines)
    for i, line in ipairs(lines) do
        local text = _displayable(line)
        local ctrl = self._lines[i]
        if not ctrl then
            ctrl = Text(self, text, Consts.FOREGROUND_COLOR, fonts.Kind.USER_INPUT)
            ctrl:set_scale(Consts.WATCH_OVERLAY_TEXT_SCALE)
            self._lines[i] = ctrl
        elseif ctrl:get_text() ~= text then
            ctrl:set_text(text)
        end
    end
    for i = #self._lines, #lines + 1, -1 do
        lifetime.destroy(table.remove(self._lines, i))
    end
    self:_layout()
end

---@return string[]
function WatchOverlay:get_lines()
    ---@type string[]
    local lines = {}
    for _, ctrl in ipairs(self._lines) do
        table.insert(lines, ctrl:get_text())
    end
    return lines
end

---@param key love.KeyConstant
function WatchOverlay:on_key_pressed(key)
    if key == Consts.TOGGLE_WATCH_OVERLAY_KEY then
        self:set_visible(not self:is_visible())
    end
end

function WatchOverlay:on_resize()
    self:_rescale()
end

---@private
function WatchOverlay:_rescale()
    if app.root then
        self:set_scale(app.root:get_scale())
    end
end

---@private
function WatchOverlay:_layout()
    local padding = Consts.WATCH_OVERLAY_PADDING
    local width, y = 0, padding
    for _, ctrl in ipairs(self._lines) do
        ctrl:set_position(padding, y)
        local w, h = ctrl:get_outer_size()
        width = math.max(width, w)
        y = y + h
    end
    if #self._lines == 0 then
        self._background:set_size(0, 0)
        self:set_size(0, 0)
        return
    end
    width = width * TEXT_WIDTH_SLACK + 2 * padding
    self._background:set_size(width, y + padding)
    self:set_size(width, y + padding)
end

return WatchOverlay

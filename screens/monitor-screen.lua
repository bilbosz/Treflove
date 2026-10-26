local Consts = require("app.consts")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local Rectangle = require("controls.rectangle")
local ScrollView = require("ui.scroll-view")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local TextInput = require("ui.text-input")
local fonts = require("graphics.fonts")
local lifetime = require("lifetime")

---@class MonitorPane
---@field view ScrollView
---@field border Rectangle
---@field lines Control Holds the lines, in the view's content
---@field texts Text[] Top to bottom

---@class MonitorScreen: FormScreen
---@field private _targets MonitorTarget[]
---@field private _selected MonitorTarget|nil
---@field private _background Rectangle
---@field private _buttons TextButton[] One per target, in the targets' order
---@field private _captions string[] What each button shows
---@field private _watches MonitorPane
---@field private _log MonitorPane
---@field private _log_first integer The log line number of the first text of the log pane
---@field private _shown_revision integer|nil The selected target's revision the panes show
---@field private _line_height number
---@field private _input TextInput|nil Made again at another width, since an input keeps the size it was made with
local MonitorScreen = class("MonitorScreen", FormScreen)

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
---@return string displayable One line of UTF-8, every run of white space or control characters a single space, a byte out of a sequence `?`, at most `Consts.MONITOR_MAX_LINE_LENGTH` characters
local function _displayable(line)
    line = string.gsub(line, "%c", " ")
    line = string.gsub(line, "%s+", " ")
    ---@type string[]
    local characters = {}
    local limit = Consts.MONITOR_MAX_LINE_LENGTH
    local i = 1
    while i <= #line and #characters <= limit do
        local length = _sequence_length(string.byte(line, i))
        local sequence = string.sub(line, i, i + length - 1)
        if length == 0 or #sequence < length or string.find(sequence, "[^\128-\191]", 2) then
            sequence, length = "?", 1
        end
        table.insert(characters, sequence)
        i = i + length
    end
    if #characters > limit then
        return table.concat(characters, "", 1, limit) .. "..."
    end
    return table.concat(characters)
end

---@param target MonitorTarget
---@return string
local function _caption(target)
    return string.format("%s: %s", target:get_name(), target:get_state())
end

---@param target MonitorTarget
---@param body string
local function _log_reply(target, body)
    local prefix = Consts.MONITOR_REPLY_PREFIX
    target:append_log(prefix .. string.gsub(body, "\n", "\n" .. prefix))
end

---@param button TextButton
---@param selected boolean
local function _paint_button(button, selected)
    if button:is_selected() or button:is_focused() then
        return
    end
    button:set_color((selected or button:is_hovered()) and Consts.BUTTON_HOVER_COLOR or Consts.BUTTON_NORMAL_COLOR)
end

---@param parent Control
---@return MonitorPane
local function _create_pane(parent)
    local view = ScrollView(parent, 1, 1, true)
    local lines = Control(view:get_content())
    lines:set_position(Consts.PADDING * 0.5, Consts.PADDING * 0.5)
    return {
        view = view,
        border = Rectangle(parent, 1, 1, Consts.FOREGROUND_COLOR, true),
        lines = lines,
        texts = {}
    }
end

---@param pane MonitorPane
---@param x number
---@param y number
---@param w number
---@param h number
local function _place_pane(pane, x, y, w, h)
    pane.view:set_position(x, y)
    pane.view:set_size(w, h)
    pane.border:set_position(x, y)
    pane.border:set_size(w, h)
end

---@param pane MonitorPane
---@param text string
---@return Text
local function _create_line(pane, text)
    local line = Text(pane.lines, _displayable(text), Consts.FOREGROUND_COLOR, fonts.Kind.USER_INPUT)
    line:set_scale(Consts.MONITOR_TEXT_SCALE)
    return line
end

---@param targets MonitorTarget[] One button each, in this order; the first is selected
function MonitorScreen:init(targets)
    FormScreen.init(self)
    self._targets = targets
    self._selected = targets[1]
    self._shown_revision = nil
    self._log_first = 1
    local measure = Text(nil, "Ag", nil, fonts.Kind.USER_INPUT)
    self._line_height = measure:get_font_height() * Consts.MONITOR_TEXT_SCALE

    local w, h = assert(app.width), assert(app.height)
    self._background = Rectangle(self.screen, w, h, Consts.BACKGROUND_COLOR)
    self._buttons = {}
    self._captions = {}
    for _, target in ipairs(targets) do
        local caption = _caption(target)
        local button = TextButton(self.screen, self, caption, function()
            self:select(target)
        end)
        button:set_scale(Consts.MONITOR_TARGET_SCALE)
        table.insert(self._buttons, button)
        table.insert(self._captions, caption)
    end
    self._watches = _create_pane(self.screen)
    self._log = _create_pane(self.screen)
    self._input = nil
    self:on_resize(w, h)
end

function MonitorScreen:show()
    FormScreen.show(self)
    app.update_event:register(self, self.on_update)
    app.wheel_event:register(self, self.on_wheel_moved)
    self:on_resize(app.width, app.height)
    self:focus(self:get_input())
    self:refresh()
end

function MonitorScreen:hide()
    app.update_event:unregister(self)
    app.wheel_event:unregister(self)
    FormScreen.hide(self)
end

---@param w number
---@param h number
function MonitorScreen:on_resize(w, h)
    local p = Consts.PADDING
    self._background:set_size(w, h)
    local _, button_h = self:_layout_buttons()
    local input_h = Consts.MONITOR_INPUT_HEIGHT
    self:_fit_input(w - 2 * p):set_position(p, h - p - input_h)
    local top = p + button_h + p
    local pane_h = math.max(1, h - top - input_h - 2 * p)
    local pane_w = math.max(1, (w - 3 * p) * 0.5)
    _place_pane(self._watches, p, top, pane_w, pane_h)
    _place_pane(self._log, 2 * p + pane_w, top, pane_w, pane_h)
end

---@return MonitorTarget|nil
function MonitorScreen:get_selected()
    return self._selected
end

---@param target MonitorTarget
function MonitorScreen:select(target)
    assert(table.find_array_idx(self._targets, target), "a target of the screen")
    if self._selected ~= target then
        self._selected = target
        self._shown_revision = nil
        self:refresh()
    end
end

---@return TextButton[] One per target, in the targets' order
function MonitorScreen:get_buttons()
    return table.copy(self._buttons)
end

---@return TextInput
function MonitorScreen:get_input()
    return assert(self._input)
end

---@return string[] The watch lines shown, top to bottom
function MonitorScreen:get_watch_lines()
    return self:_get_texts(self._watches)
end

---@return string[] The log lines shown, oldest first
function MonitorScreen:get_log_lines()
    return self:_get_texts(self._log)
end

function MonitorScreen:submit()
    local target = self._selected
    local input = self:get_input()
    local text = input:get_text()
    if not target or string.find(text, "^%s*$") then
        return
    end
    input:set_text("")
    local prefix = Consts.MONITOR_WATCH_PREFIX
    if string.sub(text, 1, #prefix) == prefix then
        target:add_watch(string.sub(text, #prefix + 1), function(ok, body)
            if not ok then
                _log_reply(target, body)
            end
        end)
    else
        target:evaluate(text, function(_, body)
            _log_reply(target, body)
        end)
    end
end

---@param dt number
function MonitorScreen:on_update(dt)
    self:refresh()
end

function MonitorScreen:refresh()
    local captions_changed = false
    for i, target in ipairs(self._targets) do
        local caption = _caption(target)
        if caption ~= self._captions[i] then
            self._captions[i] = caption
            self._buttons[i]:set_text(caption)
            captions_changed = true
        end
        _paint_button(self._buttons[i], target == self._selected)
    end
    if captions_changed then
        self:_layout_buttons()
    end
    local target = self._selected
    if target and target:get_revision() ~= self._shown_revision then
        local first_shown = self._shown_revision == nil
        self._shown_revision = target:get_revision()
        self:_show_watches(target)
        self:_show_log(target, first_shown)
    end
end

---@param x number
---@param y number Vertical wheel movement, positive away from the user
function MonitorScreen:on_wheel_moved(x, y)
    if not self:is_showed() then
        return
    end
    local px, py = app.pointer_event_manager:get_position()
    for _, pane in ipairs({
        self._watches,
        self._log
    }) do
        if pane.view:get_global_aabb():is_point_inside(px, py) then
            local scroll_x, scroll_y = pane.view:get_scroll()
            pane.view:set_scroll(scroll_x, scroll_y - y * Consts.MONITOR_SCROLL_LINES * self._line_height)
        end
    end
end

---@private
---@param width number
---@return TextInput
function MonitorScreen:_fit_input(width)
    local old = self._input
    if old and old:get_size() == width then
        return old
    end
    local input = TextInput(self.screen, self, width, Consts.MONITOR_INPUT_HEIGHT, false, nil, function()
        self:submit()
    end)
    self._input = input
    if old then
        input:set_text(old:get_text())
        local focused = old:is_focused()
        lifetime.destroy(old)
        if focused then
            self:focus(input)
        end
    end
    return input
end

---@private
---@return number width
---@return number height Of the row of buttons
function MonitorScreen:_layout_buttons()
    local p = Consts.PADDING
    local x, height = p, 0
    for _, button in ipairs(self._buttons) do
        button:set_position(x, p)
        local w, h = button:get_outer_size()
        x = x + w + 2 * p
        height = math.max(height, h)
    end
    return x - p, height
end

---@private
---@param pane MonitorPane
---@return string[]
function MonitorScreen:_get_texts(pane)
    ---@type string[]
    local texts = {}
    for _, text in ipairs(pane.texts) do
        table.insert(texts, text:get_text())
    end
    return texts
end

---@private
---@param pane MonitorPane
function MonitorScreen:_fit_content(pane)
    local width = 0
    for _, text in ipairs(pane.texts) do
        width = math.max(width, (text:get_outer_size()))
    end
    pane.view:set_content_size(width + Consts.PADDING, #pane.texts * self._line_height + Consts.PADDING)
end

---@private
---@param target MonitorTarget
function MonitorScreen:_show_watches(target)
    local watches = target:get_watches()
    ---@type string[]
    local names = {}
    for name in pairs(watches) do
        table.insert(names, name)
    end
    table.sort(names)
    local pane = self._watches
    for i, name in ipairs(names) do
        local line = _displayable(name .. ": " .. watches[name].value)
        local text = pane.texts[i]
        if not text then
            text = _create_line(pane, line)
            text:set_position(0, (i - 1) * self._line_height)
            pane.texts[i] = text
        elseif text:get_text() ~= line then
            text:set_text(line)
        end
    end
    for i = #pane.texts, #names + 1, -1 do
        lifetime.destroy(table.remove(pane.texts, i))
    end
    self:_fit_content(pane)
end

---@private
---@param target MonitorTarget
---@param anew boolean The log pane shows another target's log
function MonitorScreen:_show_log(target, anew)
    local pane = self._log
    local log, log_end = target:get_log(), target:get_log_end()
    local first = log_end - #log + 1
    local scroll_x, scroll_y = pane.view:get_scroll()
    local _, max_y = pane.view:get_max_scroll()
    local following = anew or scroll_y >= max_y - 1
    if anew then
        for _, text in ipairs(pane.texts) do
            lifetime.destroy(text)
        end
        pane.texts = {}
    end
    while pane.texts[1] and self._log_first < first do
        lifetime.destroy(table.remove(pane.texts, 1))
        self._log_first = self._log_first + 1
    end
    if not pane.texts[1] then
        self._log_first = first
    end
    for number = self._log_first + #pane.texts, log_end do
        local text = _create_line(pane, log[number - first + 1])
        text:set_position(0, number * self._line_height)
        table.insert(pane.texts, text)
    end
    pane.lines:set_position(Consts.PADDING * 0.5, Consts.PADDING * 0.5 - self._log_first * self._line_height)
    self:_fit_content(pane)
    if following then
        pane.view:set_scroll(scroll_x, math.huge)
    end
end

return MonitorScreen

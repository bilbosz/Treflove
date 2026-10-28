local Consts = require("app.consts")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local Input = require("ui.input")
local Rectangle = require("controls.rectangle")
local SelectionBoxList = require("ui.selection-box-list")
local SelectionBoxRow = require("ui.selection-box-row")
local Triangle = require("controls.triangle")
local Utils = require("utils.utils")
local lifetime = require("lifetime")

---@class SelectionOption
---@field key string What the program reads and writes (`get_selected`, `set_selected`)
---@field title string What the user sees

---@class SelectionBox: Control, Input
---@field private _background Rectangle
---@field private _title Text
---@field private _arrow Triangle
---@field private _options SelectionOption[]
---@field private _selected integer|nil The index of the selected option; nil only without options
---@field private _on_change InputHandler|nil
---@field private _list SelectionBoxList|nil While open
local SelectionBox = class("SelectionBox", Control, Input)

---@param id PointerId
---@return boolean
local function _is_press(id)
    return type(id) ~= "number" or id == Consts.LEFT_MOUSE_BUTTON
end

---@param options SelectionOption[]
---@return SelectionOption[]
local function _copy_options(options)
    ---@type SelectionOption[]
    local copy = {}
    ---@type table<string, boolean>
    local keys = {}
    for i, option in ipairs(options) do
        assert_type(option.key, "string")
        assert_type(option.title, "string")
        assert(not keys[option.key], "a key is one option's")
        keys[option.key] = true
        copy[i] = {
            key = option.key,
            title = option.title
        }
    end
    return copy
end

---@private
---@param key string|nil
---@return integer|nil
function SelectionBox:_find(key)
    for i, option in ipairs(self._options) do
        if option.key == key then
            return i
        end
    end
    return nil
end

---@private
function SelectionBox:_update_view()
    if lifetime.dying(self) then -- the view died with the children
        return
    end
    ---@type number[]
    local color
    if self:is_focused() then
        color = Consts.BUTTON_SELECT_COLOR
    elseif self:is_hovered() then
        color = Consts.BUTTON_HOVER_COLOR
    elseif self:is_read_only() then
        color = Consts.BUTTON_READ_ONLY_COLOR
    else
        color = Consts.BUTTON_NORMAL_COLOR
    end
    self._background:set_color(color)
    local option = self._options[self._selected]
    self._title:set_text(option and option.title or "")
end

---@private
---@param index integer
function SelectionBox:_choose(index)
    if index == self._selected then
        return
    end
    self._selected = index
    self:_update_view()
    if self._on_change then
        self._on_change()
    end
end

---@private
---@param index integer|nil
function SelectionBox:_on_list_end(index)
    self:close()
    if index then
        self:_choose(index)
    end
end

---@private
function SelectionBox:_create_view()
    local width, height = self:get_size()
    local padding = Consts.SELECTION_BOX_PADDING
    local arrow_width, arrow_height = Consts.SELECTION_BOX_ARROW_WIDTH, Consts.SELECTION_BOX_ARROW_HEIGHT
    local arrow_x = width - padding - arrow_width
    self._background = Rectangle(self, width, height, Consts.BUTTON_NORMAL_COLOR)
    self._title = SelectionBoxRow.create_title(self, arrow_x - 2 * padding, height, "")
    local arrow = Triangle(self, arrow_width, arrow_height, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self._arrow = arrow
    arrow:set_position(arrow_x, (height - arrow_height) * 0.5)
end

---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param options SelectionOption[] May be empty
---@param on_change InputHandler|nil Run after the user picked another option, never by `set_selected` or `set_options`
function SelectionBox:init(parent, form_screen, width, height, options, on_change)
    assert_type(form_screen, FormScreen)
    Control.init(self, parent, width, height)
    self._options = _copy_options(options)
    self._selected = #self._options > 0 and 1 or nil
    self._on_change = on_change
    self._list = nil
    Input.init(self, form_screen)
    local button = self:get_button()
    button.pointer_entered:register(self, self._update_view)
    button.pointer_left:register(self, self._update_view)
    self:_create_view()
    self:_update_view()
end

---@return SelectionOption[]
function SelectionBox:get_options()
    return _copy_options(self._options)
end

---@param options SelectionOption[] May be empty; the selected key stays when it is among them, else the first option is selected
function SelectionBox:set_options(options)
    self:close()
    local key = self:get_selected()
    self._options = _copy_options(options)
    self._selected = self:_find(key) or (#self._options > 0 and 1 or nil)
    self:_update_view()
end

---@return string|nil The selected option's key; nil only without options
function SelectionBox:get_selected()
    local option = self._options[self._selected]
    return option and option.key
end

---@param key string One of the options' keys
function SelectionBox:set_selected(key)
    local index = self:_find(key)
    assert(index, "the key is not among the options")
    self:close()
    self._selected = index
    self:_update_view()
end

---@return boolean
function SelectionBox:is_open()
    return self._list ~= nil
end

function SelectionBox:open()
    if self._list or self:is_read_only() or not self._selected or not self:get_form_screen():is_showed() then
        return
    end
    ---@type string[]
    local titles = {}
    for i, option in ipairs(self._options) do
        titles[i] = option.title
    end
    self._list = SelectionBoxList(self:get_form_screen():get_control(), self, titles, self._selected, function(index)
        self:_on_list_end(index)
    end):attach_lifetime(self)
end

function SelectionBox:close()
    local list = self._list
    if not list then
        return
    end
    self._list = nil
    if lifetime.alive(list) and not lifetime.dying(list) then
        lifetime.destroy(list)
    end
end

function SelectionBox:on_screen_show()
    Input.on_screen_show(self)
    app.pointer_event_manager.pointer_down:register(self, self.on_pointer_down)
    if self:is_focused() then
        app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
    end
end

function SelectionBox:on_screen_hide()
    self:close()
    app.pointer_event_manager.pointer_down:unregister(self)
    app.keyboard_manager.key_pressed:unregister(self)
    Input.on_screen_hide(self)
end

function SelectionBox:on_focus()
    Input.on_focus(self)
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
    self:_update_view()
end

function SelectionBox:on_focus_lost()
    app.keyboard_manager.key_pressed:unregister(self)
    Input.on_focus_lost(self)
    self:close()
    self:_update_view()
end

function SelectionBox:on_read_only_change()
    Input.on_read_only_change(self)
    if self:is_read_only() then
        self:close()
    end
    self:_update_view()
end

---@param x number
---@param y number
---@param id PointerId
---@return boolean|nil
function SelectionBox:on_pointer_down(x, y, id)
    if not _is_press(id) or self:is_read_only() then
        return true
    end
    self:get_form_screen():focus(self)
    if self._list then
        self:close()
    else
        self:open()
    end
end

---@param key love.KeyConstant
function SelectionBox:on_key_pressed(key)
    if self:is_read_only() then
        return
    end
    local list = self._list
    if list then
        if key == "up" then
            list:move_highlight(-1)
        elseif key == "down" then
            list:move_highlight(1)
        elseif key == "return" then
            self:_on_list_end(list:get_highlighted())
        end
    elseif key == "return" or key == "space" then
        self:open()
    elseif (key == "up" or key == "down") and self._selected then
        self:_choose(Utils.clamp(1, #self._options, self._selected + (key == "up" and -1 or 1)))
    end
end

return SelectionBox

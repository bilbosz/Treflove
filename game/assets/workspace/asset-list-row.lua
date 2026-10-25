local Consts = require("app.consts")
local Input = require("ui.input")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")

---@class AssetListRow: Rectangle, Input
---@field private _list AssetList
---@field private _entry AssetEntry
---@field private _label Text
---@field private _is_selected boolean
local AssetListRow = class("AssetListRow", Rectangle, Input)

---@private
function AssetListRow:_update_color()
    ---@type number[]
    local color
    if self._is_selected then
        color = Consts.ASSET_LIST_ROW_SELECTED_COLOR
    elseif self:is_focused() or self:is_selected() or self:is_hovered() then
        color = Consts.ASSET_LIST_ROW_HOVER_COLOR
    else
        color = Consts.ASSET_LIST_ROW_NORMAL_COLOR
    end
    self:set_color(color)
end

---@param list AssetList
---@param parent Control
---@param form_screen FormScreen
---@param width number
---@param height number
---@param entry AssetEntry
function AssetListRow:init(list, parent, form_screen, width, height, entry)
    Rectangle.init(self, parent, width, height, Consts.ASSET_LIST_ROW_NORMAL_COLOR)
    Input.init(self, form_screen)
    self._list = list
    self._entry = entry
    self._is_selected = false

    local label = Text(self, AssetListRow.get_label(entry), Consts.FOREGROUND_COLOR)
    self._label = label
    local s = Consts.PANEL_FIELD_SCALE
    label:set_scale(s)
    label:set_position(Consts.PADDING * 0.5, (height - label:get_font_height() * s) * 0.5)

    local button = self:get_button()
    button.selected:register(self, self._update_color)
    button.unselected:register(self, self._update_color)
    button.pointer_entered:register(self, self._update_color)
    button.pointer_left:register(self, self._update_color)
    button.clicked:register(self, self.on_click)
end

---@param entry AssetEntry
---@return string The entry's name, with a trailing `/` for a folder
function AssetListRow.get_label(entry)
    local name = string.match(entry.path, "([^/]*)$")
    return entry.type == "directory" and name .. "/" or name
end

---@return AssetEntry
function AssetListRow:get_entry()
    return self._entry
end

---@param value boolean
function AssetListRow:set_selected(value)
    self._is_selected = value
    self:_update_color()
end

function AssetListRow:on_screen_show()
    Input.on_screen_show(self)
    if self:is_focused() then
        app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
    end
end

function AssetListRow:on_screen_hide()
    Input.on_screen_hide(self)
    app.keyboard_manager.key_pressed:unregister(self)
end

function AssetListRow:on_focus()
    Input.on_focus(self)
    self:_update_color()
    app.keyboard_manager.key_pressed:register(self, self.on_key_pressed)
end

function AssetListRow:on_focus_lost()
    app.keyboard_manager.key_pressed:unregister(self)
    Input.on_focus_lost(self)
    self:_update_color()
end

function AssetListRow:on_click()
    self._list:on_row_clicked(self)
end

---@param key love.KeyConstant
function AssetListRow:on_key_pressed(key)
    if key == "return" then
        self._list:on_row_clicked(self)
    end
end

return AssetListRow

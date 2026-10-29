local AssetListRow = require("game.assets.workspace.asset-list-row")
local ClippingRectangle = require("controls.clipping-rectangle")
local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")
local Text = require("controls.text")
local lifetime = require("lifetime")

---@class AssetList: ClippingRectangle
---@field private _screen AssetsWorkspaceScreen
---@field private _border Rectangle
---@field private _rows_parent Control Holds the rows, moved up by the scroll
---@field private _rows AssetListRow[]
---@field private _empty_label Text|nil Shown in an empty folder
---@field private _row_height number
---@field private _scroll number Model units hidden above the top
local AssetList = class("AssetList", ClippingRectangle)

---@param a AssetEntry
---@param b AssetEntry
---@return boolean
local function _folders_first(a, b)
    if a.type ~= b.type then
        return a.type == "directory"
    end
    return a.path < b.path
end

---@param screen AssetsWorkspaceScreen
---@param parent Control
---@param width number
---@param height number
function AssetList:init(screen, parent, width, height)
    ClippingRectangle.init(self, parent, width, height)
    self._screen = screen
    self._border = Rectangle(self, width, height, Consts.FOREGROUND_COLOR, true)
    self._rows_parent = Control(self)
    self._rows = {}
    self._empty_label = nil
    self._scroll = 0

    local measure = Text(nil, "Ag")
    self._row_height = measure:get_font_height() * Consts.PANEL_FIELD_SCALE + Consts.PADDING * 0.5

    app.pointer_event_manager.wheel:register(self, self.on_wheel)
end

---@private
function AssetList:_clear()
    for _, row in ipairs(self._rows) do
        lifetime.destroy(row)
    end
    self._rows = {}
    if self._empty_label then
        lifetime.destroy(self._empty_label)
        self._empty_label = nil
    end
end

---@private
---@return number
function AssetList:_get_max_scroll()
    local _, h = self:get_size()
    return math.max(0, #self._rows * self._row_height - h)
end

---@private
function AssetList:_disable_rows_out_of_view()
    local _, h = self:get_size()
    for i, row in ipairs(self._rows) do
        local top = (i - 1) * self._row_height - self._scroll
        row:set_enabled(top + self._row_height > 0 and top < h)
    end
end

---@private
function AssetList:_apply_scroll()
    self._scroll = math.max(0, math.min(self:_get_max_scroll(), self._scroll))
    self._rows_parent:set_position(0, -self._scroll)
    self:_disable_rows_out_of_view()
end

---@param entries AssetEntry[] The folder's content, in any order
---@param selected_path string|nil The entry shown as selected
function AssetList:set_entries(entries, selected_path)
    self:_clear()
    local sorted = table.copy(entries)
    table.sort(sorted, _folders_first)
    local w = self:get_size()
    for i, entry in ipairs(sorted) do
        local row = AssetListRow(self, self._rows_parent, self._screen, w, self._row_height, entry)
        row:set_position(0, (i - 1) * self._row_height)
        row:set_selected(entry.path == selected_path)
        table.insert(self._rows, row)
    end
    if #sorted == 0 then
        local label = Text(self._rows_parent, "(empty)", Consts.BUTTON_READ_ONLY_COLOR)
        self._empty_label = label
        label:set_scale(Consts.PANEL_FIELD_SCALE)
        label:set_position(Consts.PADDING * 0.5, Consts.PADDING * 0.5)
    end
    self:_apply_scroll()
end

---@param selected_path string|nil
function AssetList:set_selected(selected_path)
    for _, row in ipairs(self._rows) do
        row:set_selected(row:get_entry().path == selected_path)
    end
end

function AssetList:scroll_to_top()
    self._scroll = 0
    self:_apply_scroll()
end

---@return AssetListRow[]
function AssetList:get_rows()
    return table.copy(self._rows)
end

---@param row AssetListRow
function AssetList:on_row_clicked(row)
    self._screen:on_entry_clicked(row:get_entry())
end

---@param x number
---@param y number
---@param dx number
---@param dy number Positive scrolls toward the top
---@return boolean|nil
function AssetList:on_wheel(x, y, dx, dy)
    self._scroll = self._scroll - dy * Consts.ASSET_LIST_SCROLL_ROWS * self._row_height
    self:_apply_scroll()
end

---@param w number
---@param h number
function AssetList:on_resize(w, h)
    self:set_size(w, h)
    self._border:set_size(w, h)
    for _, row in ipairs(self._rows) do
        row:set_size(w, self._row_height)
    end
    self:_apply_scroll()
end

return AssetList

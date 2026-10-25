local Consts = require("app.consts")
local Panel = require("ui.panel")
local ScrollView = require("ui.scroll-view")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local asset_usage = require("data.asset-usage")
local lifetime = require("lifetime")

---@class AssetUsageList: Panel
---@field private _screen AssetsWorkspaceScreen
---@field private _title Text
---@field private _scroll_view ScrollView Holds the buttons, under the title
---@field private _buttons TextButton[] One per use, in the order of `asset_usage.find`
---@field private _empty_label Text|nil Shown without a use
local AssetUsageList = class("AssetUsageList", Panel)

---@param screen AssetsWorkspaceScreen
---@param parent Control
---@param width number
---@param height number
function AssetUsageList:init(screen, parent, width, height)
    Panel.init(self, parent, width, height)
    self._screen = screen
    self._buttons = {}
    self._empty_label = nil
    local title = Text(self, "Used by", Consts.FOREGROUND_COLOR)
    self._title = title
    title:set_scale(Consts.PANEL_FIELD_SCALE)
    title:set_position(Consts.PADDING, Consts.PADDING)
    self._scroll_view = ScrollView(self, width, height, true)
    self:_layout()
    self:set_uses({})
end

---@private
function AssetUsageList:_layout()
    local w, h = self:get_size()
    local _, title_y, _, title_h = self._title:get_position_and_outer_size()
    local top = title_y + title_h + Consts.PADDING * 0.5
    self._scroll_view:set_position(0, top)
    self._scroll_view:set_size(w, math.max(0, h - top))
    self._scroll_view:set_content_size(w, select(2, self._scroll_view:get_content_size()))
end

---@private
function AssetUsageList:_clear()
    for _, button in ipairs(self._buttons) do
        lifetime.destroy(button)
    end
    self._buttons = {}
    if self._empty_label then
        lifetime.destroy(self._empty_label)
        self._empty_label = nil
    end
end

---@param uses AssetUse[]
function AssetUsageList:set_uses(uses)
    self:_clear()
    local content = self._scroll_view:get_content()
    local w = self:get_size()
    local s = Consts.PANEL_FIELD_SCALE
    local y = 0
    for _, use in ipairs(uses) do
        local button = TextButton(content, self._screen, asset_usage.describe(use), function()
            self._screen:go_to_use(use)
        end)
        button:set_scale(s)
        button:set_read_only(not asset_usage.is_on_shown_page(assert(app.data), use))
        button:set_position(Consts.PADDING, y)
        local _, button_h = button:get_size()
        y = y + button_h * s + Consts.PADDING * 0.5
        table.insert(self._buttons, button)
    end
    if #uses == 0 then
        local label = Text(content, "Nothing", Consts.BUTTON_READ_ONLY_COLOR)
        self._empty_label = label
        label:set_scale(s)
        label:set_position(Consts.PADDING, 0)
        y = select(2, label:get_outer_size())
    end
    self._scroll_view:set_content_size(w, y)
end

---@return TextButton[]
function AssetUsageList:get_buttons()
    return self._buttons
end

---@param w number
---@param h number
function AssetUsageList:on_resize(w, h)
    Panel.on_resize(self, w, h)
    self:_layout()
end

return AssetUsageList

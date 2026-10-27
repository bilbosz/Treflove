local Consts = require("app.consts")
local ScrollView = require("ui.scroll-view")
local SidePanel = require("game.side-panel")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local entries = require("game.entry.entries")
local lifetime = require("lifetime")
local permissions = require("game.permissions")

---@class GamePanel: SidePanel
---@field private _title Text
---@field private _page_label Text The shown page's id
---@field private _scroll_view ScrollView Holds the buttons, under the shown page's id
---@field private _buttons TextButton[] One per page the client holds, by sorted id, the shown one active
local GamePanel = class("GamePanel", SidePanel)

---@param game_screen GameScreen
---@param width number
---@param height number
function GamePanel:init(game_screen, width, height)
    SidePanel.init(self, game_screen, width, height)
    self._buttons = {}
    local s = Consts.PANEL_FIELD_SCALE
    local title = Text(self, "Shown page", Consts.FOREGROUND_COLOR)
    self._title = title
    title:set_scale(s)
    title:set_position(Consts.PADDING, Consts.PADDING)
    local label = Text(self, "", Consts.FOREGROUND_COLOR)
    self._page_label = label
    label:set_scale(s)
    self._scroll_view = ScrollView(self, width, height, true)
    self:_update_view()
end

---@param w number
---@param h number
function GamePanel:on_resize(w, h)
    SidePanel.on_resize(self, w, h)
    self:_update_view()
end

---@param kind EntryKind
---@param id string
function GamePanel:on_entries_change(kind, id)
    if kind == "game" or kind == "pages" then
        self:_update_view()
    end
end

function GamePanel:on_grants_change()
    self:_update_view()
end

---@return TextButton[] One per page the client holds, by sorted id
function GamePanel:get_buttons()
    return self._buttons
end

---@private
function GamePanel:_update_view()
    self:_layout()
    self:_create_buttons()
end

---@private
function GamePanel:_layout()
    local w, h = self:get_size()
    local data = assert(app.data)
    local label = self._page_label
    label:set_text(data.game.page)
    local _, title_y, _, title_h = self._title:get_position_and_outer_size()
    label:set_position(Consts.PADDING, title_y + title_h)
    local _, label_y, _, label_h = label:get_position_and_outer_size()
    local top = label_y + label_h + Consts.PADDING
    self._scroll_view:set_position(0, top)
    self._scroll_view:set_size(w, math.max(0, h - top - Consts.PADDING))
end

---@private
function GamePanel:_create_buttons()
    for _, button in ipairs(self._buttons) do
        lifetime.destroy(button)
    end
    self._buttons = {}
    local data = assert(app.data)
    local shown = data.game.page
    local session = assert(app.session)
    local writable = session:is_allowed(permissions.Action.WRITE, permissions.Kind.GAME, entries.GAME_ID)
    local content = self._scroll_view:get_content()
    local s = Consts.PANEL_FIELD_SCALE
    local y = 0
    for _, id in ipairs(entries.list(data, "pages")) do
        local button = TextButton(content, self._game_screen, id, function()
            self:_show(id)
        end)
        button:set_scale(s)
        button:set_active(id == shown)
        button:set_read_only(not writable)
        button:set_position(Consts.PADDING, y)
        local _, button_h = button:get_size()
        y = y + button_h * s + Consts.PADDING * 0.5
        table.insert(self._buttons, button)
    end
    self._scroll_view:set_content_size(self:get_size(), y)
end

---@private
---@param id string A page the client holds
function GamePanel:_show(id)
    if id ~= assert(app.data).game.page then
        assert(app.session):update_entry("game", entries.GAME_ID, {
            page = id
        })
    end
end

return GamePanel

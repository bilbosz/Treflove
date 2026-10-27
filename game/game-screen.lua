local Model = require("data.model")
local FormScreen = require("ui.form-screen")
local Page = require("game.page.page")
local TokenPanel = require("game.token.token-panel")
local GamePanel = require("game.panels.game-panel")
local QuickAccessPanel = require("game.quick-access-panel")
local Consts = require("app.consts")
local permissions = require("game.permissions")
local entries = require("game.entry.entries")
local lifetime = require("lifetime")

---@class GameScreen: Model, FormScreen
---@field data GameScreenData
---@field get_data fun(self: GameScreen): GameScreenData
---@field private _page Page
---@field private _token_panel TokenPanel
---@field private _game_panel GamePanel
---@field private _panel SidePanel|nil The shown side panel; `nil` while the side bar is hidden and the page's view extends over its strip
---@field private _panels SidePanel[] In the order of their quick access entries
---@field private _panel_buttons table<SidePanel, TextButton> The quick access entry that toggles each side panel, active while it is shown
---@field private _quick_access_panel QuickAccessPanel
---@field private _new_token_button TextButton Read-only without `write` on the tokens kind
local GameScreen = class("GameScreen", Model, FormScreen)

---@param data GameScreenData
function GameScreen:init(data)
    Model.init(self, data)
    FormScreen.init(self)

    local w, h = assert(app.width), assert(app.height)
    local panel_w = w * Consts.GAME_SIDE_PANEL_SHARE
    self._page = Page(app.data.pages[data.page], self, w - panel_w, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self._token_panel = TokenPanel(self, panel_w, h)
    self._game_panel = GamePanel(self, panel_w, h)
    self._panel = nil
    self._panels = {}
    self._panel_buttons = {}

    self._quick_access_panel = QuickAccessPanel(self, w - panel_w, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self:add_side_panel(self._token_panel, "Tokens")
    self._quick_access_panel:add_entry("Assets", function()
        assert(app.session):open_assets_workspace()
    end)
    self._new_token_button = self._quick_access_panel:add_entry("New Token", function()
        assert(app.session):show_new_token()
    end)
    self:_gate_new_token()
    self:add_side_panel(self._game_panel, "Game")
    self:_set_panel(self._token_panel)
end

---@param panel SidePanel Built over this screen; hidden until its entry, or `select_panel`, shows it
---@param caption string Its quick access entry's
---@return TextButton The quick access entry that toggles it
function GameScreen:add_side_panel(panel, caption)
    assert(not table.find_array_idx(self._panels, panel))
    table.insert(self._panels, panel)
    panel:set_enabled(false)
    local button = self._quick_access_panel:add_entry(caption, function()
        self:toggle_panel(panel)
    end)
    self._panel_buttons[panel] = button
    return button
end

---@private
function GameScreen:_gate_new_token()
    local session = app.session
    self._new_token_button:set_read_only(not (session and session:is_allowed(permissions.Action.WRITE, permissions.Kind.TOKENS)))
end

function GameScreen:show()
    self:on_resize(assert(app.width), assert(app.height))
    FormScreen.show(self)
end

function GameScreen:on_selection_change()
    for _, panel in ipairs(self._panels) do
        panel:on_selection_change()
    end
end

---@param kind EntryKind
---@param id string The entry's id after the change: the new one of a rename, the deleted one of a deletion
function GameScreen:on_entries_change(kind, id)
    for _, panel in ipairs(self._panels) do
        panel:on_entries_change(kind, id)
    end
end

function GameScreen:on_grants_change()
    self:_gate_new_token()
    for _, panel in ipairs(self._panels) do
        panel:on_grants_change()
    end
end

---@param id string A key of `app.data.pages` whose assets are in the store, the one `app.data.game.page` names now
function GameScreen:show_page(id)
    local old = self._page
    local x, y = old:get_position()
    local fit_w, fit_h = old:get_fit_size()
    local extension = old:get_extension()
    local index = assert(table.find_array_idx(self:get_control():get_children(), old))
    lifetime.destroy(old)
    local page = Page(assert(app.data.pages[id], "the page is held"), self, fit_w, fit_h)
    self._page = page
    page:reattach(index)
    page:set_position(x, y)
    page:set_extension(extension)
    self:on_selection_change()
    self:on_entries_change("game", entries.GAME_ID)
    self:on_entries_change("pages", id)
end

---@param w number
---@param h number
function GameScreen:on_resize(w, h)
    local panel_w = w * Consts.GAME_SIDE_PANEL_SHARE

    self._page:set_position(0, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self._page:set_size(w - panel_w, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self:_extend_over_panel()

    for _, panel in ipairs(self._panels) do
        panel:set_position(w - panel_w, 0)
        panel:on_resize(panel_w, h)
    end
end

---@private
function GameScreen:_extend_over_panel()
    local w = assert(app.width)
    local panel_w = w * Consts.GAME_SIDE_PANEL_SHARE
    local extension = self._panel and 0 or panel_w
    self._page:set_extension(extension)
    self._quick_access_panel:set_position(0, 0)
    self._quick_access_panel:on_resize(w - panel_w + extension, Consts.QUICK_ACCESS_PANEL_HEIGHT)
end

---@return Page
function GameScreen:get_page()
    return self._page
end

---@return Selection
function GameScreen:get_selection()
    return self._page:get_selection()
end

---@return TokenPanel
function GameScreen:get_token_panel()
    return self._token_panel
end

---@return GamePanel
function GameScreen:get_game_panel()
    return self._game_panel
end

---@return SidePanel|nil The shown side panel
function GameScreen:get_panel()
    return self._panel
end

---@param panel SidePanel Hidden when it is the shown one, shown otherwise: a click on its quick access entry
function GameScreen:toggle_panel(panel)
    if self._panel == panel then
        self:disable_panel()
    else
        self:select_panel(panel)
    end
end

---@param panel SidePanel
function GameScreen:select_panel(panel)
    assert(table.find_array_idx(self._panels, panel))
    self:_set_panel(panel)
    self:_extend_over_panel()
end

function GameScreen:disable_panel()
    self:_set_panel(nil)
    self:_extend_over_panel()
end

---@private
---@param panel SidePanel|nil
function GameScreen:_set_panel(panel)
    local previous = self._panel
    if previous then
        previous:set_enabled(false)
        self._panel_buttons[previous]:set_active(false)
    end
    self._panel = panel
    if panel then
        panel:set_enabled(true)
        self._panel_buttons[panel]:set_active(true)
    end
end

return GameScreen

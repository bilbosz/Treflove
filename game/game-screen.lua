local Model = require("data.model")
local FormScreen = require("ui.form-screen")
local Page = require("game.page.page")
local TokenPanel = require("game.token.token-panel")
local QuickAccessPanel = require("game.quick-access-panel")
local Consts = require("app.consts")

---@class GameScreen: Model, FormScreen
---@field data GameScreenData
---@field get_data fun(self: GameScreen): GameScreenData
---@field private _page Page
---@field private _token_panel TokenPanel
---@field private _panel Panel|nil The shown side panel; `nil` while the side bar is hidden and the page's view extends over its strip
---@field private _panels Panel[]
---@field private _panel_buttons table<Panel, TextButton> The quick access entry that toggles each side panel, active while it is shown
---@field private _quick_access_panel QuickAccessPanel
local GameScreen = class("GameScreen", Model, FormScreen)

---@param data GameScreenData
function GameScreen:init(data)
    Model.init(self, data)
    FormScreen.init(self)

    local w, h = assert(app.width), assert(app.height)
    local panel_w = w * Consts.GAME_SIDE_PANEL_SHARE
    self._page = Page(app.data.pages[data.page], self, w - panel_w, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self._token_panel = TokenPanel(self, panel_w, h)
    self._panel = nil
    self._panels = {
        self._token_panel
    }

    self._quick_access_panel = QuickAccessPanel(self, w - panel_w, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self._panel_buttons = {}
    self._panel_buttons[self._token_panel] = self._quick_access_panel:add_entry("Tokens", function()
        self:toggle_panel(self._token_panel)
    end)
    self._quick_access_panel:add_entry("Assets", function()
        assert(app.session):open_assets_workspace()
    end)
    self:_set_panel(self._token_panel)
end

function GameScreen:show()
    self:on_resize(assert(app.width), assert(app.height))
    FormScreen.show(self)
end

function GameScreen:on_selection_change()
    self._token_panel:on_selection_change()
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

---@return Panel|nil The shown side panel
function GameScreen:get_panel()
    return self._panel
end

---@param panel Panel Hidden when it is the shown one, shown otherwise: a click on its quick access entry
function GameScreen:toggle_panel(panel)
    if self._panel == panel then
        self:disable_panel()
    else
        self:select_panel(panel)
    end
end

---@param panel Panel
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
---@param panel Panel|nil
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

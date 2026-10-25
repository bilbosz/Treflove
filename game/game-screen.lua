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
---@field private _panel Panel|nil Currently selected side panel
---@field private _panels Panel[]
---@field private _quick_access_panel QuickAccessPanel
local GameScreen = class("GameScreen", Model, FormScreen)

---@param data GameScreenData
function GameScreen:init(data)
    Model.init(self, data)
    FormScreen.init(self)

    self._page = Page(app.data.pages[data.page], self, app.width * 0.8, app.height)

    self._token_panel = TokenPanel(self, app.width * 0.2, app.height)
    self._panel = self._token_panel
    self._panels = {
        self._token_panel
    }

    self._quick_access_panel = QuickAccessPanel(self, app.width * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self._quick_access_panel:add_entry("Tokens", function()
        self:select_panel(self._token_panel)
    end)
    self._quick_access_panel:add_entry("Assets", function()
        assert(app.session):open_assets_workspace()
    end)
end

function GameScreen:show()
    self:on_resize(app.width, app.height)
    FormScreen.show(self)
end

function GameScreen:on_selection_change()
    self._token_panel:on_selection_change()
end

---@param w number
---@param h number
function GameScreen:on_resize(w, h)
    self._page:set_position(0, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self._page:set_size(w * 0.8, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self._quick_access_panel:set_position(0, 0)
    self._quick_access_panel:on_resize(w * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self._token_panel:set_position(w * 0.8, 0)
    self._token_panel:on_resize(w * 0.2, h)
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

---@param panel Panel
function GameScreen:select_panel(panel)
    assert(table.find_array_idx(self._panels, panel))
    self:disable_panel()
    self._panel = panel
    panel:set_enabled(true)
end

function GameScreen:disable_panel()
    if self._panel then
        self._panel:set_enabled(false)
        self._panel = nil
    end
end

return GameScreen

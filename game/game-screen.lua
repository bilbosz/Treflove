local Model = require("data.model")
local FormScreen = require("ui.form-screen")
local Page = require("game.page.page")
local TokenPanel = require("game.token.token-panel")
local AssetsPanel = require("game.assets.assets-panel")
local QuickAccessPanel = require("game.quick-access-panel")
local Consts = require("app.consts")
local UserMenuScreen = require("screens.user-menu-screen")

---@class GameScreen: Model, FormScreen
---@field _page Page
---@field _token_panel TokenPanel
---@field _assets_panel AssetsPanel
---@field _panel Panel|nil Currently selected side panel
---@field _panels Panel[]
---@field _quick_access_panel QuickAccessPanel
local GameScreen = class("GameScreen", Model, FormScreen)

---@param data table Game data (a `game` entry of the persisted state)
function GameScreen:init(data)
    Model.init(self, data)
    FormScreen.init(self)

    self._page = Page(app.data.pages[data.page], self, app.width * 0.8, app.height)

    self._token_panel = TokenPanel(self, app.width * 0.2, app.height)
    self._assets_panel = AssetsPanel(self, app.width * 0.2, app.height)

    self._panel = self._assets_panel
    local panels = {
        self._token_panel,
        self._assets_panel
    }
    self._panels = panels
    for _, v in ipairs(panels) do
        if v ~= self._panel then
            v:set_enabled(false)
        end
    end

    self._quick_access_panel = QuickAccessPanel(self, app.width * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self._quick_access_panel:add_entry("Tokens", self._token_panel)
    self._quick_access_panel:add_entry("Assets", self._assets_panel)
end

function GameScreen:release()
    self._assets_panel:release()
end

function GameScreen:show()
    self:on_resize(app.width, app.height)
    FormScreen.show(self)
    app.backstack_manager:push(function()
        self:release()
        app.screen_manager:show(UserMenuScreen(app.session))
    end)
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

    self._assets_panel:set_position(w * 0.8, 0)
    self._assets_panel:on_resize(w * 0.2, h)
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

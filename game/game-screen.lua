local Model = require("data.model")
local FormScreen = require("ui.form-screen")
local Page = require("game.page.page")
local TokenPanel = require("game.token.token-panel")
local AssetsPanel = require("game.assets.assets-panel")
local QuickAccessPanel = require("game.quick-access-panel")
local Consts = require("app.consts")
local UserMenuScreen = require("screens.user-menu-screen")

---@class GameScreen: Model, FormScreen
local GameScreen = class("GameScreen", Model, FormScreen)

function GameScreen:init(data)
    Model.init(self, data)
    FormScreen.init(self)

    self.page = Page(app.data.pages[data.page], self, app.width * 0.8, app.height)

    self.token_panel = TokenPanel(self, app.width * 0.2, app.height)
    self.assets_panel = AssetsPanel(self, app.width * 0.2, app.height)

    self.panel = self.assets_panel
    local panels = {
        self.token_panel,
        self.assets_panel
    }
    self.panels = panels
    for _, v in ipairs(panels) do
        if v ~= self.panel then
            v:set_enabled(false)
        end
    end

    self.quick_access_panel = QuickAccessPanel(self, app.width * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self.quick_access_panel:add_entry("Tokens", self.token_panel)
    self.quick_access_panel:add_entry("Assets", self.assets_panel)
end

function GameScreen:release()
    self.assets_panel:release()
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
    self.token_panel:on_selection_change()
end

function GameScreen:on_resize(w, h)
    self.page:set_position(0, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self.page:set_size(w * 0.8, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self.quick_access_panel:set_position(0, 0)
    self.quick_access_panel:on_resize(w * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self.token_panel:set_position(w * 0.8, 0)
    self.token_panel:on_resize(w * 0.2, h)

    self.assets_panel:set_position(w * 0.8, 0)
    self.assets_panel:on_resize(w * 0.2, h)
end

function GameScreen:get_page()
    return self.page
end

function GameScreen:get_selection()
    return self.page:get_selection()
end

function GameScreen:get_token_panel()
    return self.token_panel
end

function GameScreen:select_panel(panel)
    assert(table.find_array_idx(self.panels, panel))
    self:disable_panel()
    self.panel = panel
    panel:set_enabled(true)
end

function GameScreen:disable_panel()
    if self.panel then
        self.panel:set_enabled(false)
        self.panel = nil
    end
end

return GameScreen

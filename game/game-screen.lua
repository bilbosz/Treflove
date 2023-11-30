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

    self.tokenPanel = TokenPanel(self, app.width * 0.2, app.height)
    self.assetsPanel = AssetsPanel(self, app.width * 0.2, app.height)

    self.panel = self.assetsPanel
    local panels = {
        self.tokenPanel,
        self.assetsPanel
    }
    self.panels = panels
    for _, v in ipairs(panels) do
        if v ~= self.panel then
            v:set_enabled(false)
        end
    end

    self.quickAccessPanel = QuickAccessPanel(self, app.width * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self.quickAccessPanel:AddEntry("Tokens", self.tokenPanel)
    self.quickAccessPanel:AddEntry("Assets", self.assetsPanel)
end

function GameScreen:release()
    self.assetsPanel:release()
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
    self.tokenPanel:on_selection_change()
end

function GameScreen:on_resize(w, h)
    self.page:set_position(0, Consts.QUICK_ACCESS_PANEL_HEIGHT)
    self.page:set_size(w * 0.8, h - Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self.quickAccessPanel:set_position(0, 0)
    self.quickAccessPanel:on_resize(w * 0.8, Consts.QUICK_ACCESS_PANEL_HEIGHT)

    self.tokenPanel:set_position(w * 0.8, 0)
    self.tokenPanel:on_resize(w * 0.2, h)

    self.assetsPanel:set_position(w * 0.8, 0)
    self.assetsPanel:on_resize(w * 0.2, h)
end

function GameScreen:get_page()
    return self.page
end

function GameScreen:get_selection()
    return self.page:get_selection()
end

function GameScreen:get_token_panel()
    return self.tokenPanel
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

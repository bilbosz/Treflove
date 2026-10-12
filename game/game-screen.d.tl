-- game/game-screen.lua (still Lua): the game view: the page, the side
-- panels and the quick-access bar.

-- The `game` entry of the persisted state (GameState.game), the model data
-- of the GameScreen.
global record GameScreenData
    page: string -- the name of the current page (a key of GameState.pages)
end

global interface GameScreen is Model, FormScreen
    data: GameScreenData
    _page: Page
    _token_panel: TokenPanel
    -- lifetime: anchored to the screen (`AssetsPanel(...) @ self`); Phase 0
    -- writes lifetime.attach and still releases it in `release`.
    _assets_panel: AssetsPanel
    _panel: Panel -- the selected side panel, nil when none is
    _panels: {Panel}
    _quick_access_panel: QuickAccessPanel
    on_selection_change: function(self)
    get_page: function(self): Page
    get_selection: function(self): Selection
    get_token_panel: function(self): TokenPanel
    select_panel: function(self, panel: Panel)
    disable_panel: function(self)
end

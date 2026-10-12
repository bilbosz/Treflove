-- game/quick-access-panel.lua (still Lua): the bar of buttons selecting
-- the game screen's side panels.
global interface QuickAccessPanel is Panel
    _game_screen: GameScreen
    _entries: {Panel: TextButton} -- the selecting button by its panel
    add_entry: function(self, label: string, entry: Panel)
end

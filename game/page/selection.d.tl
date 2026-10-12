-- game/page/selection.lua (still Lua): the rectangle selecting tokens on a
-- page.
global interface Selection is Rectangle
    _page: Page
    _start_point: {number, number}
    _end_point: {number, number}
    _select_set: {Token: boolean} -- the selected tokens
    show: function(self)
    hide: function(self)
    set_start_point: function(self, x: number, y: number)
    set_end_point: function(self, x: number, y: number)
    apply: function(self)
    add_apply: function(self)
    toggle_apply: function(self)
    unselect: function(self)
    get_select_set: function(self): {Token: boolean}
    on_selection_change: function(self)
    on_update: function(self) -- on app.update_event
end

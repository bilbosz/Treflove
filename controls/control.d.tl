-- controls/control.lua (still Lua). PARTIAL: only what the converted
-- modules use (utils/utils.tlt, app/app.d.tl); the phase that converts
-- controls/ completes this declaration.
global interface Control is Tree
    children: {Control}
    is_enabled: function(self): boolean
    is_visible: function(self): boolean
    are_all_predecessors_enabled: function(self): boolean
    get_children: function(self): {Control}
    get_global_recursive_aabb: function(self): Aabb
    set_scale: function(self, scale: number)
    draw: function(self)
end

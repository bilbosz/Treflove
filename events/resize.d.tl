-- events/resize.lua (still Lua): the window size and fullscreen state.
global interface ResizeManager is Object
    -- Triggered with (width, height) of the rescaled root after every
    -- resize.
    resized: Event
    _width: number -- the remembered non-fullscreen window width
    _height: number -- the remembered non-fullscreen window height
    _update_non_fs_size: function(self)
    resize: function(self)
    get_dimensions: function(self): number, number
    toggle_fullscreen: function(self)
    set_fullscreen: function(self, value: boolean)
    get_fullscreen: function(self): boolean
end

-- controls/circle.lua (still Lua): a circle outline.
global interface Circle is DrawableControl
    _color: {number}
    _diameter: number
    _line_width: number
    _radius: number
    set_radius: function(self, radius: number)
end

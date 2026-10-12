-- controls/rectangle.tlt: a filled or outlined rectangle.
global interface Rectangle is Control
    _color: {number}
    _mode: love.DrawMode
    set_color: function(self, color: {number})
    get_color: function(self): {number}
end

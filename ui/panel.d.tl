-- ui/panel.lua (still Lua): a clipped panel with a background.
global interface Panel is ClippingRectangle
    _background: Rectangle
    _create_background: function(self)
    on_resize: function(self, w: number, h: number)
end

-- controls/drawable-control.lua (still Lua): a control drawn by a callback
-- in its own coordinates.
global type DrawCb = function()

global interface DrawableControl is Control
    _draw_cb: DrawCb
    set_draw_callback: function(self, draw_cb: DrawCb) -- protected
end

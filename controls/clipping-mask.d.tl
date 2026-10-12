-- controls/clipping-mask.lua (still Lua): clips its children to the
-- stencil a callback draws.
global type StencilCallback = function()
global type DrawMaskCallback = function()

global interface ClippingMask is Control
    _stencil_cb: StencilCallback
    set_draw_mask_callback: function(self, draw_mask_cb: DrawMaskCallback)
end

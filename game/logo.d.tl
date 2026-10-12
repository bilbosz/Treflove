-- game/logo.lua (still Lua): the Treflove logo.
global interface Logo is DrawableControl
    _mask: ClippingMask
    color: {number} -- foreground; its channels may be changed from outside (ScreenSaver)
end

-- game/logo.tlt: the Treflove logo (constructor: `Logo(parent: Control)`).
global interface Logo is DrawableControl
    _mask: ClippingMask
    color: {number} -- foreground; its channels may be changed from outside (ScreenSaver)
end

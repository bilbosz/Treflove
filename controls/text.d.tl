-- controls/text.lua (still Lua): a single-font text, sized to fit it.
global interface Text is DrawableControl
    _text: string
    _font: love.Font
    _color: {number}
    _text_drawable: love.Text
    set_color: function(self, color: {number})
    get_color: function(self): {number}
    set_text: function(self, text: string)
    get_text: function(self): string
end

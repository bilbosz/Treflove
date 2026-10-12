-- ui/text-button.tlt: a text that acts on click or return.
global type TextButtonAction = function()

global interface TextButton is Text, Input
    _action: TextButtonAction
    _update_text_color: function(self)
    on_click: function(self) -- on the button's `clicked`
    on_key_pressed: function(self, key: love.KeyConstant) -- while focused
end

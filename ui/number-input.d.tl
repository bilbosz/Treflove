-- ui/number-input.lua (still Lua): a text field that accepts numbers only.
global interface NumberInput is TextInput
    _number: number -- nil when the text is not a valid number
    set_number: function(self, number: number)
    get_number: function(self): number
end

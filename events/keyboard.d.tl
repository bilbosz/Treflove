-- events/keyboard.tlt
global interface KeyboardManager is Object
    key_pressed: Event -- triggered with (key: love.KeyConstant)
    key_released: Event -- triggered with (key: love.KeyConstant)
    dispatch_key_pressed: function(self, key: love.KeyConstant)
    dispatch_key_released: function(self, key: love.KeyConstant)
    is_key_down: function(self, key: love.KeyConstant): boolean
end

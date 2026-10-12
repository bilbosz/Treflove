-- ui/form-screen.lua (still Lua): a screen with focusable inputs (tab
-- moves the focus).
global interface FormScreen is Screen
    _focus: integer -- index into _inputs, nil when nothing has focus
    _inputs: {Input}
    _is_showed: boolean
    _prev_focus: integer
    -- lifetime: set by `release`, so that an input's unlinking hook knows
    -- the form went first (lua-lifetime trial, idiom B).
    _is_released: boolean
    _notify_listeners: function(self)
    _advance_focus: function(self, d: integer) -- d is 1 or -1
    is_showed: function(self): boolean
    -- lifetime: true once the form's `release` has run.
    is_released: function(self): boolean
    on_key_pressed: function(self, key: love.KeyConstant) -- on app.keyboard_manager.key_pressed
    add_input: function(self, input: Input)
    remove_input: function(self, input: Input)
    read_only_change: function(self, input: Input)
    focus: function(self, input: Input)
    remove_all_inputs: function(self)
    -- release (Object) -- lifetime: sets _is_released.
end

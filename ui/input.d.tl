-- ui/input.lua (still Lua): a focusable form element. At runtime a mixin
-- with no base (`class("Input")`), always mixed into a Control-derived
-- class (TextButton is Text, Input; TextInput is Control, Input), which
-- `is Control` reflects. lifetime: `Input:init` attaches a hook
-- `!@ (form_screen, self)` that removes the input from its form unless the
-- form was released first (docs/lifetime.md; FormScreen.is_released).
global interface Input is Control
    _button: Button
    _form_screen: FormScreen
    _is_focused: boolean
    _is_read_only: boolean
    get_button: function(self): Button
    is_hovered: function(self): boolean
    is_selected: function(self): boolean
    get_form_screen: function(self): FormScreen
    set_read_only: function(self, value: boolean)
    is_read_only: function(self): boolean
    on_read_only_change: function(self)
    on_screen_show: function(self)
    on_screen_hide: function(self)
    on_focus: function(self)
    on_focus_lost: function(self)
    is_focused: function(self): boolean
end

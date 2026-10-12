-- ui/button-event.lua (still Lua): drives the Button of the control under
-- the pointer from raw pointer input.
global interface ButtonEventManager is Object
    _buttons: {Control: Button} -- the registered button per control (weak keys)
    _hover: Button -- the button under the pointer
    _selection: Button -- the button pressed and not yet released
    register: function(self, ctrl: Control, button: Button)
    unregister: function(self, ctrl: Control)
    _get_button: function(self, x: number, y: number): Button
    dispatch_pointer_down: function(self, x: number, y: number, id: PointerId)
    dispatch_pointer_up: function(self, x: number, y: number, id: PointerId)
    dispatch_pointer_move: function(self, x: number, y: number, id: PointerId)
end

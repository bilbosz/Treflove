-- ui/button.lua (still Lua): the pointer button behaviour composed into
-- every Input; ButtonEventManager drives its state, and each change is
-- announced on its events, all triggered with no arguments.
global interface Button is Object
    clicked: Event -- pressed and released over the same control
    -- Pressed over the control, or dragged back onto it while pressed.
    selected: Event
    -- The pressed pointer dragged off the control, or released over it
    -- (before `clicked`).
    unselected: Event
    pointer_entered: Event
    pointer_left: Event
    _hovered: boolean
    _selected: boolean
    is_hovered: function(self): boolean
    is_selected: function(self): boolean
    enter: function(self)
    leave: function(self)
    select: function(self)
    unselect: function(self)
    click: function(self)
end

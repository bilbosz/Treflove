-- ui/menu/menu-entry.lua (still Lua): an entry of a MenuScreen, which
-- creates its control when the menu is laid out.
global interface MenuEntry is Object
    control: Control -- nil until create_control
    create_control: function(self, parent: Control): Control -- abstract
    get_control: function(self): Control
end

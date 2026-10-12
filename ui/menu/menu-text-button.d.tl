-- ui/menu/menu-text-button.lua (still Lua)
global interface MenuTextButton is MenuEntry
    _screen: MenuScreen
    _label: string
    _cb: TextButtonAction
end

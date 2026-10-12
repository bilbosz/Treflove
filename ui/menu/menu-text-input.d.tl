-- ui/menu/menu-text-input.tlt
global interface MenuTextInput is MenuEntry
    _field_name: string
    _input: TextInput -- nil until create_control
    _masked: boolean
    _on_enter: TextInputCallback
    _screen: MenuScreen
    get_text: function(self): string
end

-- screens/menu-screen.tlt: a form of menu entries under the
-- logo and a title.
global interface MenuScreen is FormScreen
    _background: Rectangle
    _entries: {MenuEntry}
    _layout: Control
    _title: string
    _create_background: function(self)
    _create_layout: function(self)
    _create_logo: function(self)
    _create_title: function(self)
    _center_layout: function(self)
    _create_entries: function(self)
end

-- screens/waiting-screen.tlt: a message under a spinning logo.
global interface WaitingScreen is Screen
    _background: Rectangle
    _layout: Control
    _logo: Logo
    _message: string
    _text: Text
    _create_background: function(self)
    _create_layout: function(self)
    _create_logo: function(self)
    _create_text: function(self)
    _center_layout: function(self)
    on_update: function(self, dt: number) -- on app.update_event
end

-- screens/screen-manager.tlt: shows one screen at a time.
global interface ScreenManager is Object
    _screen: Screen
    show: function(self, screen: Screen)
    on_resize: function(self, w: number, h: number) -- on app.resize_manager.resized
    get_screen: function(self): Screen
end

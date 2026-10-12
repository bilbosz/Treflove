-- screens/screen.tlt: a full-screen UI container, shown under app.root by
-- the ScreenManager.
global interface Screen is Object
    screen: Control -- the root control of the screen
    show: function(self)
    hide: function(self)
    on_resize: function(self, w: number, h: number)
    get_control: function(self): Control
end

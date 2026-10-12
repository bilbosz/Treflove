-- screens/screen-saver.lua (still Lua): the server's screen when it has a
-- window.
global interface ScreenSaver is Screen
    _background: Rectangle
    _dir_rot: number
    _dir_x: number
    _dir_y: number
    _logo: Logo
    on_update: function(self, dt: number) -- on app.update_event
end

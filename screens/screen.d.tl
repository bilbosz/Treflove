-- screens/screen.lua (still Lua): a full-screen UI container, shown under
-- app.root by the ScreenManager.
global interface Screen is Object
    screen: Control -- the root control of the screen
    -- Lua: `show(...)`, the arguments ignored; the one caller passing one
    -- (UserMenuScreen:options) drops it when converted.
    show: function(self)
    hide: function(self)
    on_resize: function(self, w: number, h: number)
    get_control: function(self): Control
end

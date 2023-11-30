local FormScreen = require("ui.form-screen")

---@class Input
local Input = class("Input")

function Input:init(formScreen)
    assert_type(formScreen, FormScreen)
    self.formScreen = formScreen
    self.isFocused = false
    self.isReadOnly = false
    formScreen:add_input(self)
    if formScreen:is_showed() then
        self:on_screen_show()
    end
end

function Input:get_form_screen()
    return self.formScreen
end

function Input:set_read_only(value)
    if self.isReadOnly ~= value then
        self.isReadOnly = value
        self:on_read_only_change()
    end
end

function Input:is_read_only()
    return self.isReadOnly
end

function Input:on_read_only_change()
    self.formScreen:read_only_change(self)
end

function Input:on_screen_show()
    app.button_event_manager:register_listener(self)
end

function Input:on_screen_hide()
    app.button_event_manager:unregister_listener(self)
end

function Input:on_focus()
    self.isFocused = true
end

function Input:on_focus_lost()
    self.isFocused = false
end

function Input:is_focused()
    return self.isFocused
end

return Input

-- ui/text-event.lua (still Lua): LÖVE text input and editing keys as
-- events for the focused text field.
global interface TextEventManager is Object
    text_appended: Event -- triggered with (text: string) typed by the user
    -- Triggered with (character_number: integer) to remove from the end.
    characters_removed: Event
    word_removed: Event -- triggered when the last word should be removed
    entered: Event -- triggered when return is pressed
    _keyboard: love.keyboard -- the keyboard backend (a fake in tests)
    text_input: function(self, text: string)
    key_pressed: function(self, key: love.KeyConstant)
    set_text_input: function(self, value: boolean)
    is_text_input: function(self): boolean
end

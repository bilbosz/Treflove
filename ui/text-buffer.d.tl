-- ui/text-buffer.lua (still Lua): editable UTF-8 text composed into a text
-- field.
global interface TextBuffer is Object
    edited: Event -- triggered with (text: string) after an edit changed the text
    removed_empty: Event -- triggered when removing from an already empty text
    _text: string
    remove_characters: function(self, character_number: integer) -- characters, not bytes
    remove_word: function(self)
    append_text: function(self, text: string)
    get_text: function(self): string
    set_text: function(self, text: string) -- does not trigger `edited`
    get_text_length: function(self): integer
end

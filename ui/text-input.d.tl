-- ui/text-input.tlt: a single-line text field.
global type TextInputCallback = function()

global interface TextInput is Control, Input
    _background: Rectangle
    _buffer: TextBuffer
    _caret: Rectangle
    _caret_time: number
    _clip: ClippingRectangle
    _content: Control
    _has_new_value: boolean
    _is_multivalue: boolean
    _masked: boolean
    _on_enter: TextInputCallback
    _on_input: TextInputCallback
    _padding: number
    _text_ctrl: Text
    _upload_background_view: function(self)
    _update_text_view: function(self)
    _upload_caret_view: function(self)
    _update_content_view: function(self)
    _update_view: function(self)
    _update_text_events_registration: function(self)
    _set_text_events_registered: function(self, value: boolean)
    _create_background: function(self)
    _create_clip: function(self)
    _create_caret: function(self)
    _create_text: function(self)
    _create_content: function(self)
    on_update: function(self, dt: number) -- on app.update_event while shown
    on_click: function(self)
    on_edit: function(self, text: string) -- on the buffer's `edited`
    on_enter: function(self)
    on_remove_empty: function(self)
    on_append_text: function(self, text: string)
    on_remove_characters: function(self, character_number: integer)
    on_remove_word: function(self)
    get_text: function(self): string
    get_text_length: function(self): integer
    set_text: function(self, text: string)
    set_multivalue: function(self, value: boolean)
    is_multivalue: function(self): boolean
    is_multivalue_default: function(self): boolean
end

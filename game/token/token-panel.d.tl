-- game/token/token-panel.tlt: edits the properties of the
-- selected tokens.

-- The type of a token property (GameState.token_properties).
global enum TokenPropertyType
    "string"
    "number"
    "image"
    "array"
end

-- A token property definition (GameState.token_properties).
global record TokenPropertyDef
    title: string
    type: TokenPropertyType
end

global record TokenPanelProperty
    key: string -- the token data key
    def: TokenPropertyDef
    title: Text
    input: TextInput -- a TextInput or a NumberInput, by def.type
end

global interface TokenPanel is Panel
    _game_screen: GameScreen
    _properties: {TokenPanelProperty}
    _keys: {string} -- the sorted editable keys of the selected tokens
    _selection_set: {Token: boolean}
    _cancel_button: TextButton
    _apply_button: TextButton
    on_selection_change: function(self)
    _update_view: function(self)
    _update_property_keys: function(self)
    _fill_in_properties: function(self)
    _create_property_title: function(self, property: TokenPanelProperty): Text
    _create_property_input: function(self, property: TokenPanelProperty): TextInput
    -- Whether every selected token has the same value under `key`, and that
    -- value. any: token data values are of every type (ModelData).
    _get_value_by_key: function(self, key: string): boolean, any
    _create_cancel_button: function(self)
    _create_apply_button: function(self)
    _release_properties: function(self)
    _apply: function(self)
    cancel: function(self)
end

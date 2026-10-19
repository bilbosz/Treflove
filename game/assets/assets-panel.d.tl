-- game/assets/assets-panel.tlt: previews a dropped file and uploads it to
-- the server (constructor: `AssetsPanel(game_screen: GameScreen, width:
-- number, height: number)`). Anchored to its game screen; owns its
-- preview area.
global interface AssetsPanel is Panel
    _game_screen: GameScreen
    _location_input: TextInput
    _remote_location_input: TextInput
    -- Anchored to the panel (`PreviewArea(...) @ self`).
    _preview_area: PreviewArea
    _file_type_input: TextInput
    _upload_button: TextButton
    _cancel_button: TextButton
    _media_type: Media.Type -- nil until a file is dropped
    _data: string -- the dropped file's raw content
    _data_size: number
    set_file: function(self, file: love.DroppedFile)
    reset: function(self)
    _upload: function(self)
    cancel: function(self)
end

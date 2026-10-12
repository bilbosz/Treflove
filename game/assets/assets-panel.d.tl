-- game/assets/assets-panel.lua (still Lua): previews a dropped file and
-- uploads it to the server.
global interface AssetsPanel is Panel
    _game_screen: GameScreen
    _location_input: TextInput
    _remote_location_input: TextInput
    -- lifetime: anchored to the panel (`PreviewArea(...) @ self`); Phase 0
    -- writes lifetime.attach and still releases it in `release`.
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

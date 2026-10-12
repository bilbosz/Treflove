-- game/assets/preview-area/preview-area.lua (still Lua): the drop target
-- and preview of the assets panel.

-- What PreviewArea:set_content shows: PreviewImageArea or
-- PreviewAudioArea, each a Control made with `(preview_area,
-- love_content)`. A type only: there is no PreviewComponent class at
-- runtime (both classes are `class(name, Control)`), so it cannot be passed
-- to is_instance_of. It stands for the union of the two, which Teal cannot
-- spell (one table type per union).
global interface PreviewComponent is Control
    _preview_area: PreviewArea
end

global interface PreviewArea is ClippingRectangle
    parent: AssetsPanel
    _preview_labels: Control
    _drop_file_labels: Control
    content_parent: Control -- the parent of the preview, centered in the area
    _preview: PreviewComponent
    -- On app.file_system_drop_event_manager.file_dropped.
    on_file_system_drop: function(self, x: number, y: number, dropped_file: love.DroppedFile)
    -- Shows `love_content` with the class `preview_component` (a class
    -- table: PreviewImageArea or PreviewAudioArea).
    set_content: function(self, love_content: LoveMedium, preview_component: PreviewComponent)
    reset: function(self)
    -- release (Object): unregisters from file_dropped.
end

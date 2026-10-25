local ClippingRectangle = require("controls.clipping-rectangle")
local Control = require("controls.control")
local Text = require("controls.text")
local Consts = require("app.consts")
local PreviewAudioArea = require("game.assets.preview-area.preview-audio-area")
local PreviewFontArea = require("game.assets.preview-area.preview-font-area")
local PreviewImageArea = require("game.assets.preview-area.preview-image-area")
local PreviewVideoArea = require("game.assets.preview-area.preview-video-area")
local Rectangle = require("controls.rectangle")
local lifetime = require("lifetime")
local media = require("utils.media")

---@alias PreviewComponentClass PreviewImageArea|PreviewAudioArea|PreviewVideoArea|PreviewFontArea|fun(preview_area: PreviewArea, medium: LoveMedium, data: media.Source): PreviewImageArea|PreviewAudioArea|PreviewVideoArea|PreviewFontArea A preview class table: its class joined by its constructor, as `Class` is

---@class FileDropTarget
---@field set_file fun(self: FileDropTarget, file: love.DroppedFile) Takes the file, open during the call only

---@class PreviewArea: ClippingRectangle
---@field private _drop_target FileDropTarget
---@field private _form_screen FormScreen The screen the previews' inputs belong to
---@field _preview_labels Control
---@field _drop_file_labels Control
---@field content_parent Control Parent for preview components, centered in the area
---@field private _preview PreviewImageArea|PreviewAudioArea|PreviewVideoArea|PreviewFontArea|nil
local PreviewArea = class("PreviewArea", ClippingRectangle)

local PREVIEW_STRING = "Preview"
local DROP_FILE_STRING = "Drop File Here"

---@type table<media.Type, PreviewComponentClass|nil> The types with a preview
local PREVIEW_OF_TYPE = {
    [media.Type.IMAGE] = PreviewImageArea,
    [media.Type.AUDIO] = PreviewAudioArea,
    [media.Type.VIDEO] = PreviewVideoArea,
    [media.Type.TEXT] = nil,
    [media.Type.FONT] = PreviewFontArea
}

---@param self PreviewArea
---@param str string
---@return Control
local function _create_background_labels(self, str)
    local labels = Control(self)

    local measure_label = Text(nil, str)
    measure_label:set_scale(Consts.PANEL_FIELD_SCALE)
    local w, h = measure_label:get_outer_size()

    local area_w, area_h = self:get_size()
    local desired_w, desired_h = area_w * math.sqrt(2), area_h * math.sqrt(2)
    local hor = math.ceil(desired_w / (w + Consts.PADDING) + 0.5)
    local ver = math.ceil(desired_h / (h + Consts.PADDING))
    local labels_w, labels_h = hor * (w + Consts.PADDING), ver * (h + Consts.PADDING)

    local x, y = 0, 0
    for i = 1, ver do
        for _ = 1, hor do
            local label = Text(labels, str, Consts.BACKGROUND_COLOR)
            label:set_scale(Consts.PANEL_FIELD_SCALE)
            label:set_position(x, y)
            w, h = label:get_outer_size()
            x = x + w + Consts.PADDING
        end
        x = (i % 2) * 0.5 * w
        y = y + h + Consts.PADDING
    end

    labels:set_position(area_w * 0.5, area_h * 0.5)
    labels:set_origin(labels_w * 0.5, labels_h * 0.5)
    labels:set_rotation(math.pi * 0.25)

    return labels
end

---@param self PreviewArea
---@param labels Control
local function _set_labels(self, labels)
    for _, v in ipairs({
        self._preview_labels,
        self._drop_file_labels
    }) do
        v:set_enabled(false)
    end
    labels:set_enabled(true)
end

---@param self PreviewArea
local function _create_background(self)
    local w, h = self:get_size()
    Rectangle(self, w, h, Consts.BUTTON_NORMAL_COLOR)
    self._preview_labels = _create_background_labels(self, PREVIEW_STRING)
    self._drop_file_labels = _create_background_labels(self, DROP_FILE_STRING)

    _set_labels(self, self._drop_file_labels)
end

---@param self PreviewArea
local function _create_content_parent(self)
    local control = Control(self)
    self.content_parent = control

    local w, h = self:get_size()
    control:set_position(w * 0.5, h * 0.5)
end

---@param parent Control|nil
---@param width number
---@param height number
---@param drop_target FileDropTarget Takes the file dropped on the area
---@param form_screen FormScreen The screen the previews' inputs belong to
function PreviewArea:init(parent, width, height, drop_target, form_screen)
    ClippingRectangle.init(self, parent, width, height)
    self._drop_target = drop_target
    self._form_screen = form_screen
    _create_background(self)
    _create_content_parent(self)

    self._preview = nil

    app.file_system_drop_event_manager.file_dropped:register(self, self.on_file_system_drop)
    app.file_system_drop_event_manager:set_receive_through(self, true)
end

---@param x number
---@param y number
---@param dropped_file love.DroppedFile
function PreviewArea:on_file_system_drop(x, y, dropped_file)
    local ok, err = dropped_file:open("r")
    assert(ok, err)
    lifetime.block(function(scope)
        lifetime.hook(function()
            dropped_file:close()
        end, scope)
        self._drop_target:set_file(dropped_file)
    end)
end

---@return FormScreen
function PreviewArea:get_form_screen()
    return self._form_screen
end

---@param medium LoveMedium
---@param data media.Source The file the medium was made of
---@param PreviewComponent PreviewComponentClass
function PreviewArea:set_content(medium, data, PreviewComponent)
    self:reset()
    _set_labels(self, self._preview_labels)
    self._preview = PreviewComponent(self, medium, data)
end

---@param media_type media.Type|nil
---@param medium LoveMedium Absent for a type LÖVE could not open from these bytes: no preview then
---@param data media.Source|nil The file, when it was read
function PreviewArea:show_medium(media_type, medium, data)
    local PreviewComponent = media_type and PREVIEW_OF_TYPE[media_type]
    if PreviewComponent and medium and data then
        self:set_content(medium, data, PreviewComponent)
    else
        self:reset()
    end
end

function PreviewArea:reset()
    _set_labels(self, self._drop_file_labels)
    if self._preview then
        lifetime.destroy(self._preview)
        self._preview = nil
    end
end

return PreviewArea

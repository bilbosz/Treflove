local ClippingRectangle = require("controls.clipping-rectangle")
local FileSystemDropEventListener = require("events.file-drop-event").Listener
local Control = require("controls.control")
local Text = require("controls.text")
local Consts = require("app.consts")
local Rectangle = require("controls.rectangle")

---@class PreviewArea: ClippingRectangle, FileSystemDropEventListener
---@field parent AssetsPanel
---@field preview_labels Control
---@field drop_file_labels Control
---@field content_parent Control
local PreviewArea = class("PreviewArea", ClippingRectangle, FileSystemDropEventListener)

local PREVIEW_STRING = "Preview"
local DROP_FILE_STRING = "Drop File Here"

---@param self PreviewArea
---@param str string
---@return Control
local function _create_background_labels(self, str)
    local labels = Control(self)

    local label = Text(nil, str)
    label:set_scale(Consts.PANEL_FIELD_SCALE)
    local w, h = label:get_outer_size()

    local area_w, area_h = self:get_size()
    local desired_w, desired_h = area_w * math.sqrt(2), area_h * math.sqrt(2)
    local hor = math.ceil(desired_w / (w + Consts.PADDING) + 0.5)
    local ver = math.ceil(desired_h / (h + Consts.PADDING))
    local labels_w, labels_h = hor * (w + Consts.PADDING), ver * (h + Consts.PADDING)

    local x, y, w, h = 0, 0, nil, nil
    for i = 1, ver do
        for j = 1, hor do
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
        self.preview_labels,
        self.drop_file_labels
    }) do
        v:set_enabled(false)
    end
    labels:set_enabled(true)
end

---@param self PreviewArea
local function _create_background(self)
    local w, h = self:get_size()
    Rectangle(self, w, h, Consts.BUTTON_NORMAL_COLOR)
    self.preview_labels = _create_background_labels(self, PREVIEW_STRING)
    self.drop_file_labels = _create_background_labels(self, DROP_FILE_STRING)

    _set_labels(self, self.drop_file_labels)
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
function PreviewArea:init(parent, width, height)
    ClippingRectangle.init(self, parent, width, height)
    FileSystemDropEventListener.init(self, true)
    _create_background(self)
    _create_content_parent(self)

    self.preview = nil

    app.file_system_drop_event_manager:register_listener(self)
end

---@param x number
---@param y number
---@param dropped_file love.DroppedFile
function PreviewArea:on_file_system_drop(x, y, dropped_file)
    local ok, err = dropped_file:open("r")
    assert(ok, err)
    self.parent:set_file(dropped_file)
    dropped_file:close()
end

---@param love_content LoveMedium
---@param PreviewComponent PreviewImageArea|PreviewAudioArea
function PreviewArea:set_content(love_content, PreviewComponent)
    self:reset()
    _set_labels(self, self.preview_labels)
    self.preview = PreviewComponent(self, love_content)
end

function PreviewArea:reset()
    _set_labels(self, self.drop_file_labels)
    if self.preview then
        self.preview:set_parent(nil)
    end
end

function PreviewArea:release()
    app.file_system_drop_event_manager:unregister_listener(self)
end

return PreviewArea

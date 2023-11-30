local ClippingRectangle = require("controls.clipping-rectangle")
local FileSystemDropEventListener = require("events.file-drop-event").Listener
local Control = require("controls.control")
local Text = require("controls.text")
local Consts = require("app.consts")
local Rectangle = require("controls.rectangle")

---@class PreviewArea: ClippingRectangle, FileSystemDropEventListener
local PreviewArea = class("PreviewArea", ClippingRectangle, FileSystemDropEventListener)

local PREVIEW_STRING = "Preview"
local DROP_FILE_STRING = "Drop File Here"

local function CreateBackgroundLabels(self, str)
    local labels = Control(self)

    local label = Text(nil, str)
    label:set_scale(Consts.PANEL_FIELD_SCALE)
    local w, h = label:get_outer_size()

    local areaW, areaH = self:get_size()
    local desiredW, desiredH = areaW * math.sqrt(2), areaH * math.sqrt(2)
    local hor = math.ceil(desiredW / (w + Consts.PADDING) + 0.5)
    local ver = math.ceil(desiredH / (h + Consts.PADDING))
    local labelsW, labelsH = hor * (w + Consts.PADDING), ver * (h + Consts.PADDING)

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

    labels:set_position(areaW * 0.5, areaH * 0.5)
    labels:set_origin(labelsW * 0.5, labelsH * 0.5)
    labels:set_rotation(math.pi * 0.25)

    return labels
end

local function SetLabels(self, labels)
    for _, v in ipairs({
        self.previewLabels,
        self.dropFileLabels
    }) do
        v:set_enabled(false)
    end
    labels:set_enabled(true)
end

local function CreateBackground(self)
    local w, h = self:get_size()
    local background = Rectangle(self, w, h, Consts.BUTTON_NORMAL_COLOR)
    self.previewLabels = CreateBackgroundLabels(self, PREVIEW_STRING)
    self.dropFileLabels = CreateBackgroundLabels(self, DROP_FILE_STRING)

    SetLabels(self, self.dropFileLabels)
end

local function CreateContentParent(self)
    local control = Control(self)
    self.contentParent = control

    local w, h = self:get_size()
    control:set_position(w * 0.5, h * 0.5)
end

function PreviewArea:init(parent, width, height)
    ClippingRectangle.init(self, parent, width, height)
    FileSystemDropEventListener.init(self, true)
    CreateBackground(self)
    CreateContentParent(self)

    self.preview = nil

    app.file_system_drop_event_manager:register_listener(self)
end

function PreviewArea:on_file_system_drop(x, y, droppedFile)
    local ok, err = droppedFile:open("r")
    assert(ok, err)
    self.parent:SetFile(droppedFile)
    droppedFile:close()
end

function PreviewArea:SetContent(loveContent, Preview)
    self:reset()
    SetLabels(self, self.previewLabels)
    self.preview = Preview(self, loveContent)
end

function PreviewArea:reset()
    SetLabels(self, self.dropFileLabels)
    if self.preview then
        self.preview:set_parent(nil)
    end
end

function PreviewArea:release()
    app.file_system_drop_event_manager:unregister_listener(self)
end

return PreviewArea

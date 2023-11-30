local Model = require("data.model")
local Control = require("controls.control")
local PointerEventListener = require("events.pointer-event").Listener
local ClippingMask = require("controls.clipping-mask")
local Image = require("controls.image")
local Consts = require("app.consts")
local Circle = require("controls.circle")
local Text = require("controls.text")

---@class Token: Model, Control, PointerEventListener
local Token = class("Token", Model, Control, PointerEventListener)

local function CreateAvatar(self, path)
    local d = self.d
    local r = d * 0.5
    local clip = ClippingMask(self, d, d, function()
        love.graphics.circle("fill", r, r, r)
    end)
    self.clip = clip
    clip:set_origin(r, r)

    local img = Image(clip, path)
    self.image = img

    local imgW, imgH = img:get_size()
    local scaleW, scaleH = d / imgW, d / imgH
    img:set_origin(imgW * 0.5, imgH * 0.5)
    img:set_scale(math.max(scaleW, scaleH))
    img:set_position(r, r)
end

local function CenterLabel(self)
    local label = self.label
    local s = 0.007
    local w, h = label:get_size()
    label:set_origin(w * 0.5, h * 0.5)
    label:set_scale(s)
    label:set_position(0, self.d * 0.5 + Consts.TOKEN_SELECTION_THICKNESS + h * s * 0.5)
end

local function CreateLabel(self, label)
    self.label = Text(self, label)
    CenterLabel(self)
end

local function CreateSelectionEffect(self)
    local r = self.d * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
    local circle = Circle(self, r, Consts.TOKEN_SELECTION_COLOR, Consts.TOKEN_SELECTION_THICKNESS)
    circle:set_position(-r, -r)

    self.selection = circle
    self.selection:set_enabled(false)
end

function Token:init(data, parent)
    Model.init(self, data)
    Control.init(self, parent)
    PointerEventListener.init(self)

    self.dragMouseButton = 1
    self.prevDragMouseX, self.prevDragMouseY = nil, nil

    self.d = data.diameter
    self:set_position(unpack(data.position))
    CreateAvatar(self, data.avatar)
    CreateLabel(self, data.name)
    CreateSelectionEffect(self)

    self.isSelected = false

    app.pointer_event_manager:register_listener(self)
end

function Token:GetRadius()
    return self.data.diameter * 0.5
end

function Token:SetSelect(value)
    self.isSelected = value
    self.selection:set_enabled(value)
    if value then
        self:reattach()
    end
end

function Token:GetSelect()
    return self.isSelected
end

function Token:set_position(x, y)
    local pos = self.data.position
    pos[1], pos[2] = x, y
    Control.set_position(self, x, y)
end

function Token:set_data(key, value)
    Model.set_data(self, key, value)
    if key == "name" then
        self.label:set_text(self.data.name)
        CenterLabel(self)
    elseif key == "diameter" then
        self.d = self.data.diameter
        local d = self.d
        local r = d * 0.5

        local clip = self.clip
        clip:set_size(d, d)
        clip:set_origin(r, r)
        clip:set_draw_mask_callback(function()
            love.graphics.circle("fill", r, r, r)
        end)

        local img = self.image
        local imgW, imgH = img:get_size()
        local scaleW, scaleH = d / imgW, d / imgH
        img:set_origin(imgW * 0.5, imgH * 0.5)
        img:set_scale(math.max(scaleW, scaleH))
        img:set_position(r, r)

        local selectionR = self.d * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
        local selection = self.selection
        selection:set_radius(selectionR, selectionR)
        selection:set_position(-selectionR, -selectionR)

        CenterLabel(self)
    end
end

return Token

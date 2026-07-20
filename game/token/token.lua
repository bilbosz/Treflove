local Model = require("data.model")
local Control = require("controls.control")
local PointerEventListener = require("events.pointer-event").Listener
local ClippingMask = require("controls.clipping-mask")
local Image = require("controls.image")
local Consts = require("app.consts")
local Circle = require("controls.circle")
local Text = require("controls.text")

---@class TokenData
---@field name string
---@field diameter number Token diameter in meters
---@field position number[]
---@field avatar string Path of the avatar image asset

---@class Token: Model, Control, PointerEventListener
---@field _diameter number
---@field _clip ClippingMask
---@field _image Image
---@field _label Text
---@field _selection Circle Selection-highlight circle
---@field _is_selected boolean
---@field _drag_mouse_button number
---@field _prev_drag_mouse_x number|nil
---@field _prev_drag_mouse_y number|nil
local Token = class("Token", Model, Control, PointerEventListener)

---@param self Token
---@param path string Avatar image asset path
local function _create_avatar(self, path)
    local d = self._diameter
    local r = d * 0.5
    local clip = ClippingMask(self, d, d, function()
        love.graphics.circle("fill", r, r, r)
    end)
    self._clip = clip
    clip:set_origin(r, r)

    local img = Image(clip, path)
    self._image = img

    local img_w, img_h = img:get_size()
    local scale_w, scale_h = d / img_w, d / img_h
    img:set_origin(img_w * 0.5, img_h * 0.5)
    img:set_scale(math.max(scale_w, scale_h))
    img:set_position(r, r)
end

---@param self Token
local function _center_label(self)
    local label = self._label
    local s = 0.007
    local w, h = label:get_size()
    label:set_origin(w * 0.5, h * 0.5)
    label:set_scale(s)
    label:set_position(0, self._diameter * 0.5 + Consts.TOKEN_SELECTION_THICKNESS + h * s * 0.5)
end

---@param self Token
---@param label string
local function _create_label(self, label)
    self._label = Text(self, label)
    _center_label(self)
end

---@param self Token
local function _create_selection_effect(self)
    local r = self._diameter * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
    local circle = Circle(self, r, Consts.TOKEN_SELECTION_COLOR, Consts.TOKEN_SELECTION_THICKNESS)
    circle:set_position(-r, -r)

    self._selection = circle
    self._selection:set_enabled(false)
end

---@param data TokenData
---@param parent Control
function Token:init(data, parent)
    Model.init(self, data)
    Control.init(self, parent)
    PointerEventListener.init(self)

    self._drag_mouse_button = 1
    self._prev_drag_mouse_x, self._prev_drag_mouse_y = nil, nil

    self._diameter = data.diameter
    self:set_position(unpack(data.position))
    _create_avatar(self, data.avatar)
    _create_label(self, data.name)
    _create_selection_effect(self)

    self._is_selected = false

    app.pointer_event_manager:register_listener(self)
end

---@return number
function Token:get_radius()
    return self.data.diameter * 0.5
end

---@param value boolean
function Token:set_select(value)
    self._is_selected = value
    self._selection:set_enabled(value)
    if value then
        self:reattach()
    end
end

---@return boolean
function Token:get_select()
    return self._is_selected
end

---@param x number
---@param y number
function Token:set_position(x, y)
    local pos = self.data.position
    pos[1], pos[2] = x, y
    Control.set_position(self, x, y)
end

---@param key string|number
---@param value any
function Token:set_data(key, value)
    Model.set_data(self, key, value)
    if key == "name" then
        self._label:set_text(self.data.name)
        _center_label(self)
    elseif key == "diameter" then
        self._diameter = self.data.diameter
        local d = self._diameter
        local r = d * 0.5

        local clip = self._clip
        clip:set_size(d, d)
        clip:set_origin(r, r)
        clip:set_draw_mask_callback(function()
            love.graphics.circle("fill", r, r, r)
        end)

        local img = self._image
        local img_w, img_h = img:get_size()
        local scale_w, scale_h = d / img_w, d / img_h
        img:set_origin(img_w * 0.5, img_h * 0.5)
        img:set_scale(math.max(scale_w, scale_h))
        img:set_position(r, r)

        local selection_r = self._diameter * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
        local selection = self._selection
        selection:set_radius(selection_r)
        selection:set_position(-selection_r, -selection_r)

        _center_label(self)
    end
end

return Token

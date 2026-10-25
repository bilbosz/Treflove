local Model = require("data.model")
local Control = require("controls.control")
local ClippingMask = require("controls.clipping-mask")
local Image = require("controls.image")
local Consts = require("app.consts")
local Circle = require("controls.circle")
local Text = require("controls.text")
local permissions = require("game.permissions")
local lifetime = require("lifetime")

---@alias TokenDataValue string|number|string[]|number[] The value of a token property, by its `TokenPropertyType`: `string`, `number`, `image` (an asset path) or `array`

---@class TokenData
---@field name string
---@field diameter number Token diameter in meters
---@field position {[1]: number, [2]: number} Position on the page, in meters
---@field avatar string Path of the avatar image asset
---@field owners string[]|nil Logins of the players who own the token
---@field [string] TokenDataValue By a key of `GameData.token_properties`

---@class Token: Model, Control
---@field data TokenData
---@field get_data fun(self: Token): TokenData
---@field private _key string The token's key in `GameData.tokens`
---@field _diameter number
---@field _clip ClippingMask
---@field _image Image
---@field _label Text
---@field _selection Circle Selection-highlight circle
---@field private _is_selected boolean
---@field private _drag_mouse_button number
---@field private _prev_drag_mouse_x number|nil
---@field private _prev_drag_mouse_y number|nil
local Token = class("Token", Model, Control)

---@param self Token
local function _fit_avatar(self)
    local d = self._diameter
    local r = d * 0.5
    local img = self._image
    local img_w, img_h = img:get_size()
    img:set_origin(img_w * 0.5, img_h * 0.5)
    img:set_scale(math.max(d / img_w, d / img_h))
    img:set_position(r, r)
end

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
    self._image = Image(clip, path)
    _fit_avatar(self)
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

---@param key string The token's key in `GameData.tokens`, which the permissions name
---@param data TokenData
---@param parent Control
function Token:init(key, data, parent)
    assert_type(key, "string")
    Model.init(self, data)
    Control.init(self, parent)
    self._key = key

    self._drag_mouse_button = 1
    self._prev_drag_mouse_x, self._prev_drag_mouse_y = nil, nil

    self._diameter = data.diameter
    self:set_position(unpack(data.position))
    _create_avatar(self, data.avatar)
    _create_label(self, data.name)
    _create_selection_effect(self)

    self._is_selected = false

    local pointer_event_manager = app.pointer_event_manager
    pointer_event_manager.pointer_down:register(self, self.on_pointer_event)
    pointer_event_manager.pointer_up:register(self, self.on_pointer_event)
    pointer_event_manager.pointer_move:register(self, self.on_pointer_event)
end

---@param x number
---@param y number
---@param id PointerId
function Token:on_pointer_event(x, y, id)

end

---@return string
function Token:get_key()
    return self._key
end

---@return boolean Whether the logged-in player may change the token
function Token:is_writable()
    return assert(app.session):get_permissions():allows(permissions.Action.WRITE, permissions.Kind.TOKENS, self._key)
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

---@param key string A key of `GameData.token_properties`
---@param value TokenDataValue|nil
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

        _fit_avatar(self)

        local selection_r = self._diameter * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
        local selection = self._selection
        selection:set_radius(selection_r)
        selection:set_position(-selection_r, -selection_r)

        _center_label(self)
    elseif key == "avatar" then
        lifetime.destroy(self._image)
        self._image = Image(self._clip, self.data.avatar)
        _fit_avatar(self)
    end
end

return Token

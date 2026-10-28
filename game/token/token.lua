local Model = require("data.model")
local Control = require("controls.control")
local Avatar = require("game.token.avatar")
local Consts = require("app.consts")
local Circle = require("controls.circle")
local Text = require("controls.text")
local permissions = require("game.permissions")
local token_id = require("game.token.token-id")

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
---@field private _id string The token's key in `GameData.tokens`
---@field _diameter number
---@field _avatar Avatar
---@field _label Text
---@field _selection Circle Selection-highlight circle
---@field private _is_selected boolean
---@field private _drag_mouse_button number
---@field private _prev_drag_mouse_x number|nil
---@field private _prev_drag_mouse_y number|nil
local Token = class("Token", Model, Control)

---@param self Token
---@param path string Avatar image asset path
local function _create_avatar(self, path)
    local d = self._diameter
    local avatar = Avatar(self, path, d)
    avatar:set_origin(d * 0.5, d * 0.5)
    self._avatar = avatar
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

---@param id string The token's key in `GameData.tokens`, which the pages and the permissions name
---@param data TokenData
---@param parent Control
function Token:init(id, data, parent)
    assert_type(id, "string")
    Model.init(self, data)
    Control.init(self, parent)
    self._id = id

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
function Token:get_id()
    return self._id
end

---@param id string One `token_id.check` accepts
function Token:set_id(id)
    local old = self._id
    token_id.rename(assert(app.data), old, id)
    self._id = id
    assert(app.session):get_permissions():rename_key(permissions.Kind.TOKENS, old, id)
end

---@return boolean Whether the logged-in player may change the token
function Token:is_writable()
    return assert(app.session):get_permissions():allows(permissions.Action.WRITE, permissions.Kind.TOKENS, self._id)
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

        local avatar = self._avatar
        avatar:set_diameter(d)
        avatar:set_origin(r, r)

        local selection_r = self._diameter * 0.5 - Consts.TOKEN_SELECTION_THICKNESS * 0.5
        local selection = self._selection
        selection:set_radius(selection_r)
        selection:set_position(-selection_r, -selection_r)

        _center_label(self)
    elseif key == "avatar" then
        self._avatar:set_image(self.data.avatar)
    end
end

return Token

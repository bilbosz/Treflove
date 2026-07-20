local Panel = require("ui.panel")
local Consts = require("app.consts")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local NumberInput = require("ui.number-input")
local TextButton = require("ui.text-button")

---@class TokenPanelProperty
---@field key string Token data key
---@field def table Property definition from `token_properties`
---@field title Text|nil
---@field input TextInput|NumberInput|nil

---@class TokenPanel: Panel
---@field _game_screen GameScreen
---@field _properties TokenPanelProperty[]
---@field _keys string[]|nil Sorted editable keys of the selected tokens
---@field _selection_set table<Token, boolean>
---@field _cancel_button TextButton|nil
---@field _apply_button TextButton|nil
local TokenPanel = class("TokenPanel", Panel)

---@param game_screen GameScreen
---@param width number
---@param height number
function TokenPanel:init(game_screen, width, height)
    Panel.init(self, game_screen:get_control(), width, height)
    self._game_screen = game_screen
    self._properties = {}
    self._keys = nil
    self._selection_set = game_screen:get_selection():get_select_set()
    self._cancel_button = nil
    self._apply_button = nil
end

---@param w number
---@param h number
function TokenPanel:on_resize(w, h)
    Panel.on_resize(self, w, h)
    self:_update_view()
end

function TokenPanel:on_selection_change()
    self._selection_set = self._game_screen:get_selection():get_select_set()
    self:_update_view()
end

---@private
function TokenPanel:_update_view()
    self:_release_properties()
    self:_update_property_keys()
    self:_fill_in_properties()
    self:_create_cancel_button()
    self:_create_apply_button()
end

---@private
function TokenPanel:_update_property_keys()
    local unique_keys = {}
    for token in pairs(self._selection_set) do
        for k in pairs(token:get_data()) do
            unique_keys[k] = true
        end
    end
    local keys = {}
    for k in pairs(unique_keys) do
        local t = app.data.token_properties[k].type
        if t == "string" or t == "number" then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    self._keys = keys
end

---@private
function TokenPanel:_fill_in_properties()
    local y = 0
    for _, k in ipairs(self._keys) do
        if app.data.token_properties[k] then
            local property = {
                key = k,
                def = app.data.token_properties[k],
                title = nil,
                input = nil
            }

            do
                local title = self:_create_property_title(property)
                property.title = title
                title:set_position(Consts.PADDING, y)
                local h = select(2, title:get_size())
                y = y + h * title:get_scale()
            end

            do
                local input = self:_create_property_input(property)
                property.input = input
                input:set_position(Consts.PADDING, y)
                local h = select(2, input:get_size())
                y = y + h

                local is_single_value, value = self:_get_value_by_key(k)
                if is_single_value then
                    local t = property.def.type
                    if t == "string" then
                        input:set_text(value)
                    elseif t == "number" then
                        input:set_number(value)
                    end
                else
                    input:set_multivalue(true)
                end
            end

            table.insert(self._properties, property)

            y = y + Consts.PADDING
        end
    end
end

---@private
---@param property TokenPanelProperty
---@return Text
function TokenPanel:_create_property_title(property)
    local title = Text(self, property.def.title, Consts.FOREGROUND_COLOR)
    title:set_scale(Consts.PANEL_FIELD_SCALE)
    return title
end

---@private
---@param property TokenPanelProperty
---@return TextInput|NumberInput
function TokenPanel:_create_property_input(property)
    local panel_w = self:get_size()

    local t = property.def.type
    local apply = function()
        self:_apply()
    end

    local input
    if t == "string" then
        input = TextInput(self, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, nil, apply)
    elseif t == "number" then
        input = NumberInput(self, self._game_screen, panel_w - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, nil, apply)
    else
        assert_unreachable()
    end
    return input
end

---@private
---@param key string
---@return boolean is_single_value
---@return any value Common value when all selected tokens agree
function TokenPanel:_get_value_by_key(key)
    local once = true
    local value
    for token in pairs(self._selection_set) do
        local current = token:get_data()[key]
        if once then
            once = false
            value = current
        elseif value ~= current then
            return false, nil
        end
    end
    return true, value
end

---@private
function TokenPanel:_create_cancel_button()
    local h = select(2, self:get_size())

    local button = TextButton(self, self._game_screen, "Cancel", function()
        self:cancel()
    end)
    self._cancel_button = button

    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_h = select(2, button:get_size())
    button:set_position(Consts.PADDING, h - button_h * s - Consts.PADDING)
end

---@private
function TokenPanel:_create_apply_button()
    local w, h = self:get_size()

    local button = TextButton(self, self._game_screen, "Apply", function()
        self:_apply()
    end)
    self._apply_button = button

    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local button_w, button_h = button:get_size()
    button:set_position(w - button_w * s - Consts.PADDING, h - button_h * s - Consts.PADDING)
end

---@private
function TokenPanel:_release_properties()
    for _, v in ipairs(self._properties) do
        v.title:set_parent(nil)

        self._game_screen:remove_input(v.input)
        v.input:set_parent(nil)
    end
    self._properties = {}

    if self._cancel_button then
        self._game_screen:remove_input(self._cancel_button)
        self._cancel_button:set_parent(nil)
        self._cancel_button = nil
    end

    if self._apply_button then
        self._game_screen:remove_input(self._apply_button)
        self._apply_button:set_parent(nil)
        self._apply_button = nil
    end
end

---@private
function TokenPanel:_apply()
    for _, property in ipairs(self._properties) do
        if not property.input:is_multivalue_default() then
            local t = property.def.type
            if t == "string" then
                local key, value = property.key, property.input:get_text()
                for token in pairs(self._selection_set) do
                    local old = token:get_data()[key]
                    if old ~= value then
                        token:set_data(key, value)
                    end
                end
            elseif t == "number" then
                local key, value = property.key, property.input:get_number()
                for token in pairs(self._selection_set) do
                    local old = token:get_data()[key]
                    if old ~= value then
                        token:set_data(key, value)
                    end
                end
            else
                assert_unreachable()
            end
        end
    end
end

function TokenPanel:cancel()
    self._game_screen:get_selection():unselect()
end

return TokenPanel

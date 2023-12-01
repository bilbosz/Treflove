local Panel = require("ui.panel")
local Consts = require("app.consts")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local NumberInput = require("ui.number-input")
local TextButton = require("ui.text-button")

---@class TokenPanel: Panel
local TokenPanel = class("TokenPanel", Panel)

function TokenPanel:init(gameScreen, width, height)
    Panel.init(self, gameScreen:get_control(), width, height)
    self.gameScreen = gameScreen
    self.properties = {}
    self.keys = nil
    self.selectionSet = gameScreen:get_selection():get_select_set()
    self.cancelButton = nil
    self.applyButton = nil
end

function TokenPanel:on_resize(w, h)
    Panel.on_resize(self, w, h)
    self:_update_view()
end

function TokenPanel:on_selection_change()
    self.selectionSet = self.gameScreen:get_selection():get_select_set()
    self:_update_view()
end

function TokenPanel:_update_view()
    self:_release_properties()
    self:_update_property_keys()
    self:_fill_in_properties()
    self:_create_cancel_button()
    self:_create_apply_button()
end

function TokenPanel:_update_property_keys()
    local uniqueKeys = {}
    for token in pairs(self.selectionSet) do
        for k in pairs(token:get_data()) do
            uniqueKeys[k] = true
        end
    end
    local keys = {}
    for k in pairs(uniqueKeys) do
        local t = app.data.token_properties[k].type
        if t == "string" or t == "number" then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    self.keys = keys
end

function TokenPanel:_fill_in_properties()
    local y = 0
    for _, k in ipairs(self.keys) do
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

                local isSingleValue, value = self:_get_value_by_key(k)
                if isSingleValue then
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

            table.insert(self.properties, property)

            y = y + Consts.PADDING
        end
    end
end

function TokenPanel:_create_property_title(property)
    local title = Text(self, property.def.title, Consts.FOREGROUND_COLOR)
    title:set_scale(Consts.PANEL_FIELD_SCALE)
    return title
end

function TokenPanel:_create_property_input(property)
    local panelW = self:get_size()

    local t = property.def.type
    local apply = function()
        self:_apply()
    end

    local input
    if t == "string" then
        input = TextInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, false, nil, apply)
    elseif t == "number" then
        input = NumberInput(self, self.gameScreen, panelW - 2 * Consts.PADDING, Consts.PANEL_TEXT_INPUT_HEIGHT, nil, apply)
    else
        assert_unreachable()
    end
    return input
end

function TokenPanel:_get_value_by_key(key)
    local once = true
    local value
    for token in pairs(self.selectionSet) do
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

function TokenPanel:_create_cancel_button()
    local h = select(2, self:get_size())

    local button = TextButton(self, self.gameScreen, "Cancel", function()
        self:cancel()
    end)
    self.cancelButton = button

    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local buttonH = select(2, button:get_size())
    button:set_position(Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

function TokenPanel:_create_apply_button()
    local w, h = self:get_size()

    local button = TextButton(self, self.gameScreen, "Apply", function()
        self:_apply()
    end)
    self.applyButton = button

    local s = Consts.PANEL_FIELD_SCALE
    button:set_scale(s)

    local buttonW, buttonH = button:get_size()
    button:set_position(w - buttonW * s - Consts.PADDING, h - buttonH * s - Consts.PADDING)
end

function TokenPanel:_release_properties()
    for _, v in ipairs(self.properties) do
        v.title:set_parent(nil)

        self.gameScreen:remove_input(v.input)
        v.input:set_parent(nil)
    end
    self.properties = {}

    if self.cancelButton then
        self.gameScreen:remove_input(self.cancelButton)
        self.cancelButton:set_parent(nil)
        self.cancelButton = nil
    end

    if self.applyButton then
        self.gameScreen:remove_input(self.applyButton)
        self.applyButton:set_parent(nil)
        self.applyButton = nil
    end
end

function TokenPanel:_apply()
    for _, property in ipairs(self.properties) do
        if not property.input:is_multivalue_default() then
            local t = property.def.type
            if t == "string" then
                local key, value = property.key, property.input:get_text()
                for token in pairs(self.selectionSet) do
                    local old = token:get_data()[key]
                    if old ~= value then
                        token:set_data(key, value)
                    end
                end
            elseif t == "number" then
                local key, value = property.key, property.input:get_number()
                for token in pairs(self.selectionSet) do
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
    self.gameScreen:get_selection():Unselect()
end

return TokenPanel

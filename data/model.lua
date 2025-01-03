require("utils.class")

---@class Model
---@field data table
local Model = class("Model")

---@param data table
function Model:init(data)
    self.data = data
end

---@return table
function Model:get_data()
    return self.data
end

---@param key string|number
---@param value any
function Model:set_data(key, value)
    self.data[key] = value
end

return Model

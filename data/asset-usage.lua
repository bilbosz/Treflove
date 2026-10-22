local Asset = require("data.asset")

---Where the game data refers to assets: a page's image and the token
---properties of the `image` type
---@class asset_usage
local asset_usage = {}

---@param value TokenDataValue|nil
---@param path string
---@return boolean Whether `value` names `path` or something under it
local function _refers(value, path)
    return type(value) == "string" and Asset.is_under(value, path)
end

---@param value string
---@param path string
---@param new_path string
---@return string `value` with its `path` prefix replaced
local function _moved(value, path, new_path)
    return new_path .. string.sub(value, #path + 1)
end

---@generic V
---@param collection table<string, V>|nil
---@return string[] The keys, sorted
local function _sorted_keys(collection)
    ---@type string[]
    local keys = {}
    for key in pairs(collection or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

---@param data GameData
---@return string[] The keys of the token properties of the `image` type, sorted
local function _image_keys(data)
    ---@type string[]
    local keys = {}
    for _, key in ipairs(_sorted_keys(data.token_properties)) do
        if data.token_properties[key].type == "image" then
            table.insert(keys, key)
        end
    end
    return keys
end

---@param data GameData
---@param path string An asset or a folder
---@return string[] What refers to `path` or to something under it, e.g. `page "Old Town"`, `token "Bilbosz" (avatar)`; empty when nothing does
function asset_usage.find(data, path)
    ---@type string[]
    local found = {}
    for _, name in ipairs(_sorted_keys(data.pages)) do
        if _refers(data.pages[name].image, path) then
            table.insert(found, string.format("page %q", name))
        end
    end
    local image_keys = _image_keys(data)
    for _, name in ipairs(_sorted_keys(data.tokens)) do
        local token = data.tokens[name]
        for _, key in ipairs(image_keys) do
            if _refers(token[key], path) then
                table.insert(found, string.format("token %q (%s)", name, key))
            end
        end
    end
    return found
end

---Points every reference to `path`, or to something under it, at `new_path`
---@param data GameData
---@param path string
---@param new_path string
function asset_usage.rename(data, path, new_path)
    for _, page in pairs(data.pages or {}) do
        if _refers(page.image, path) then
            page.image = _moved(page.image, path, new_path)
        end
    end
    local image_keys = _image_keys(data)
    for _, token in pairs(data.tokens or {}) do
        for _, key in ipairs(image_keys) do
            local value = token[key]
            if type(value) == "string" and Asset.is_under(value, path) then
                token[key] = _moved(value, path, new_path)
            end
        end
    end
end

return asset_usage

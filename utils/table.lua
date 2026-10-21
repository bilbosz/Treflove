---@type nil|fun(k: any): boolean
local is_state = nil

---@alias table.Key number|string|boolean|table|function|userdata|thread Any value but nil

---@alias table.Display fun(v: any): string A value or a key in the source form `table.to_string` writes

---@param k any
---@return boolean
local function _is_state(k)
    if not is_state then
        is_state = require("lifetime").is_state
    end
    return is_state(k)
end

---@param str string
---@return boolean
function table.is_identifier(str)
    local l = #str
    local b, e = string.find(str, "[%a_][%w_]*")
    return b == 1 and e == l
end

---@generic K, V
---@param destination table<K, V>
---@param source table<K, V>
function table.merge(destination, source)
    ---@param k any
    ---@param v any
    for k, v in pairs(source) do
        if not _is_state(k) then
            destination[k] = v
        end
    end
end

---@generic V
---@param destination table<number, V>|V[]
---@param source V[]
function table.merge_array(destination, source)
    ---@param v any
    for _, v in ipairs(source) do
        table.insert(destination, v)
    end
end

---@generic K, V
---@param source table<K, V>
---@return table<K, V>
function table.copy(source)
    ---@type table<any, any>
    local copy = {}
    ---@param k any
    ---@param v any
    for k, v in pairs(source) do
        if not _is_state(k) then
            copy[k] = v
        end
    end
    return copy
end

---@generic K, V
---@param source table<K, V>
---@return table<K, V>
function table.deep_copy(source)
    ---@type table<any, any>
    local copy = {}
    ---@param k any
    ---@param v any
    for k, v in pairs(source) do
        if not _is_state(k) then
            if type(v) == "table" then
                copy[k] = table.deep_copy(v)
            else
                copy[k] = v
            end
        end
    end
    return copy
end

---@param source table
---@return string
function table.to_string(source)
    ---@type fun(t: table<any, any>): string
    local table_display
    ---@type table<type, table.Display|nil>
    local value_display = {
        ["nil"] = tostring,
        ["boolean"] = tostring,
        ["number"] = tostring,
        ---@param v string
        ---@return string
        ["string"] = function(v)
            return "\"" .. string.gsub(v, "\n", "\\n") .. "\""
        end,
        ["function"] = nil,
        ["userdata"] = nil,
        ["thread"] = nil,
        ---@param v table
        ---@return string
        ["table"] = function(v)
            return table_display(v)
        end

    }
    ---@type table<type, table.Display|nil>
    local key_display = table.copy(value_display)
    key_display["nil"] = nil
    key_display["table"] = nil

    local depth = 0
    ---@type table<table, boolean>
    local visited = {}
    table_display = function(t)
        assert(type(t) == "table")
        assert(not visited[t])
        visited[t] = true
        depth = depth + 1
        ---@type number[]
        local nums = {}
        ---@type string[]
        local strings = {}
        ---@type table.Key[]
        local others = {}
        ---@param k table.Key
        for k in pairs(t) do
            local k_type = type(k)
            if k_type == "number" then
                table.insert(nums, k)
            elseif k_type == "string" then
                table.insert(strings, k)
            else
                table.insert(others, k)
            end
        end
        table.sort(strings)

        local prefix = string.rep("    ", depth)
        local result = "{"
        local last = 0
        ---@type table.Key[][]
        local groups = {
            nums,
            strings,
            others
        }
        for _, group in ipairs(groups) do
            ---@param k table.Key
            for _, k in ipairs(group) do
                local v = t[k]
                local k_type = type(k)
                local v_type = type(v)
                local v_display = value_display[v_type]
                if v_display then
                    local k_display = key_display[k_type]
                    if k_type == "number" and k == last + 1 then
                        result = result .. "\n" .. prefix .. v_display(v) .. ","
                        last = k
                    elseif k_type == "string" and table.is_identifier(k) then
                        result = result .. "\n" .. prefix .. k .. " = " .. v_display(v) .. ","
                    elseif k_display then
                        result = result .. "\n" .. prefix .. "[" .. k_display(k) .. "] = " .. v_display(v) .. ","
                    end
                end
            end
        end
        depth = depth - 1
        prefix = string.rep("    ", depth)
        return result .. "\n" .. prefix .. "}"
    end

    local self_type = type(source)
    local self_display = value_display[self_type]
    assert(self_display)
    return "return " .. self_display(source)
end

---@param str string
---@return table|nil
function table.from_string(str)
    local chunk, syntax_error = loadstring(str)
    if not chunk then
        app:log("Error when creating table.", tostring(syntax_error))
        return nil
    end
    ---@type boolean, any
    local no_error, result = pcall(chunk)
    if not no_error then
        app:log("Error when creating table.", tostring(result))
        return nil
    end
    return result
end

---@generic K, V
---@param tab table<K, V>
---@param value V
---@return K|nil
function table.find_table_key(tab, value)
    ---@param k any
    ---@param v any
    for k, v in pairs(tab) do
        if v == value then
            return k
        end
    end
    return nil
end

---@generic V
---@param array V[]
---@param value V
---@return number|nil
function table.find_array_idx(array, value)
    ---@param v any
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

---@param tab table
---@return boolean
function table.is_empty(tab)
    local k = next(tab)
    if k ~= nil and _is_state(k) then
        k = next(tab, k)
    end
    return k == nil
end

---@generic V
---@param t table<number, V>|V[]
---@param i number
---@return number|nil
---@return V|nil
function prev(t, i)
    if i <= 1 then
        return nil, nil
    else
        return i - 1, t[i - 1]
    end
end

---@generic V
---@param t table<number, V>|V[]
---@return fun(tbl: table<number, V>|V[], i: number):(number|nil, V|nil)
---@return table<number, V>|V[]
---@return number
function ripairs(t)
    return prev, t, #t + 1
end

---@generic K, V
---@param t table<K, V>|V[]
---@return fun(tbl: table<K, V>, key: K|nil):(K, V)
---@return table<K, V>
function cpairs(t)
    return pairs(table.copy(t))
end

---@generic V
---@param t table<number, V>|V[]
---@return fun(tbl: V[], i: number|nil):(number, V)
---@return V[]
---@return number
function cipairs(t)
    return ipairs(table.copy(t))
end

---@generic V
---@param t table<number, V>|V[]
---@return fun(tbl: table<number, V>|V[], i: number):(number|nil, V|nil)
---@return table<number, V>|V[]
---@return number
function cripairs(t)
    return ripairs(table.copy(t))
end

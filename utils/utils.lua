local Consts = require("app.consts")
local Socket = require("socket")

local Utils = {}

---@param ctrl Control
---@return void
local function _draw_aabbs_detail(ctrl)
    love.graphics.rectangle("fill", ctrl:get_global_recursive_aabb():get_position_and_size())
    for _, child in ipairs(ctrl.children) do
        if child:is_enabled() then
            _draw_aabbs_detail(child)
        end
    end
end

---@param ctrl Control
---@return void
function Utils.draw_aabbs(ctrl)
    love.graphics.setColor({
        1,
        0,
        0,
        0.1
    })
    _draw_aabbs_detail(ctrl)
    love.graphics.reset()
end

---@param ctrl Control
---@param indent string|nil
---@return string
function Utils.dump_controls(ctrl, indent)
    indent = indent or ""
    local name = get_class_name_of(ctrl)
    local dump = {}
    table.insert(dump, indent .. name .. "[")
    table.insert(dump, ctrl:is_enabled() and "e" or " ")
    table.insert(dump, ctrl:is_visible() and "v" or " ")
    table.insert(dump, ctrl:are_all_predecessors_enabled() and "a" or " ")
    table.insert(dump, "]\n")
    for _, child in ipairs(ctrl:get_children()) do
        table.insert(dump, Utils.dump_controls(child, indent .. "|   "))
    end
    return table.concat(dump)
end

---@param obj table
---@param black_functions table
---@return void
function Utils.monitor_object(obj, black_functions)
    black_functions = black_functions or {}
    local mt = getmetatable(obj)
    local old_index = mt.__index
    mt.__index = function(_, k)
        local level = 1
        local info = debug.getinfo(level, "f")
        while info do
            local f = info.func
            if table.find_array_idx(black_functions, f) then
                return old_index[k]
            end
            level = level + 1
            info = debug.getinfo(level, "f")
        end
        app:log("Read on " .. k)
        return old_index[k]
    end

    mt.__newindex = function(_, k, v)
        old_index[k] = v
        app:log("write on " .. k)
    end
end

---@param a number
---@param b number
---@param x number
---@return number
function Utils.mix(a, b, x)
    return a + x * (b - a)
end

---@param min number
---@param max number
---@param x number
---@return number
function Utils.clamp(min, max, x)
    return math.min(math.max(min, x), max)
end

---@param len number
---@return string
function Utils.generate_salt(len)
    local salt = {}
    local rng = love.math.newRandomGenerator()
    rng:setSeed(app.is_server and Consts.SERVER_SEED or Consts.CLIENT_SEED)
    for _ = 1, len do
        table.insert(salt, string.char(rng:random(0, 255)))
    end
    return love.data.encode("string", "base64", table.concat(salt))
end

---@param str string
---@return string
function Utils.hash(str)
    return love.data.encode("string", "base64", love.data.hash(Consts.HASH_ALGORITHM, str))
end

---@return number
function Utils.get_time()
    return Socket.gettime()
end

---@param min_level number
---@return string
function Utils.get_stack_trace(min_level)
    min_level = min_level or 1
    local trace = ""
    local up = 1
    local level = 1
    while true do
        local info = debug.getinfo(up, "nSl")
        if not info then
            break
        end
        if string.sub(info.source, 1, 1) == "@" then
            if level >= min_level + 1 then
                local location = string.format("%s:%i", info.short_src, info.currentline)
                if info.short_src ~= "utils/class.lua" then
                    if info.name then
                        trace = trace .. string.format("%44s in %s %s", location, info.namewhat, info.name) .. "\n"
                    else
                        trace = trace .. string.format("%44s", location) .. "\n"
                    end
                end
            end
            level = level + 1
        end
        up = up + 1
    end
    return trace
end

---@param path string
---@return string[]
function Utils.split_path(path)
    local tab = {}
    local last_found, found = 1, 0
    while true do
        found = string.find(path, "/", found + 1)
        if not found then
            break
        end

        local split = string.sub(path, last_found + 1, found - 1)
        table.insert(tab, split)

        last_found = found
    end

    local split = string.sub(path, last_found + 1, #path)
    table.insert(tab, split)

    return tab
end

---@param module string
---@return void
function Utils.error_handler(module)
    assert_type(module, "string")
    return function(msg)
        print(string.format("%s error: \"%s\"", module, msg))
        print(Utils.get_stack_trace(2))
    end
end

---Use to mark code that should not be reached
---@param msg string|nil
---@return void
function assert_unreachable(msg)
    error(msg)
end

---Use to mark abstract methods
---@return void
function abstract()
    error("Method marked as abstract has no implementation")
end

---@param value any
---@return boolean
function toboolean(value)
    return not not value
end

return Utils

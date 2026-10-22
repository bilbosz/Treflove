local Consts = require("app.consts")

---The globals a sandboxed script sees: a whitelist of the standard library,
---copied for each environment so that what a script changes stays its own,
---and what the host shares with the script. What is left out, and why, is
---in docs/scripting.md.
---@class environment
local environment = {}

---@alias environment.Output fun(line: string) Where a script's `print` writes one line

---@type string[]
local BASE_FUNCTIONS = {
    "assert",
    "error",
    "ipairs",
    "next",
    "pairs",
    "pcall",
    "rawequal",
    "rawget",
    "rawset",
    "select",
    "setmetatable",
    "tonumber",
    "tostring",
    "type",
    "unpack"
}

---@type table<string, string[]>
local LIBRARIES = {
    string = {
        "byte",
        "char",
        "find",
        "format",
        "gmatch",
        "gsub",
        "len",
        "lower",
        "match",
        "reverse",
        "sub",
        "upper"
    },
    table = {
        "concat",
        "insert",
        "maxn",
        "remove",
        "sort"
    },
    math = {
        "abs",
        "acos",
        "asin",
        "atan",
        "atan2",
        "ceil",
        "cos",
        "cosh",
        "deg",
        "exp",
        "floor",
        "fmod",
        "frexp",
        "huge",
        "ldexp",
        "log",
        "log10",
        "max",
        "min",
        "modf",
        "pi",
        "pow",
        "rad",
        "random",
        "sin",
        "sinh",
        "sqrt",
        "tan",
        "tanh"
    },
    os = {
        "clock",
        "difftime",
        "time"
    }
}

---`string.rep` with a cap on the result: one call into the C library runs
---to its end, so a result the memory limit would refuse must be refused
---before it is built
---@param s string
---@param n number
---@param sep string|nil
---@return string
local function _rep(s, n, sep)
    local count = tonumber(n)
    if not count then
        error(string.format("bad argument #2 to 'rep' (number expected, got %s)", type(n)), 2)
    end
    local length = (#tostring(s) + (sep and #tostring(sep) or 0)) * count
    if length > Consts.SCRIPT_STRING_LIMIT then
        error(string.format("string.rep: a result of %d bytes exceeds the limit of %d", length, Consts.SCRIPT_STRING_LIMIT), 2)
    end
    return string.rep(s, count, sep)
end

---`getmetatable` for tables only: the metatable of a string is shared by
---every string of the program, so reaching it would reach the host
---@param value any
---@return table|nil
local function _getmetatable(value)
    if type(value) ~= "table" then
        return nil
    end
    return getmetatable(value)
end

---@param handler function
---@param ok boolean
---@param ... any
---@return boolean, ...
local function _handled(handler, ok, ...)
    if ok then
        return true, ...
    end
    return false, handler((...))
end

---`xpcall` over `pcall`: inside the real one the handler runs with the
---instruction hook silent (LuaJIT), so a handler could loop past every limit
---@param fn function
---@param handler function
---@param ... any
---@return boolean, ...
local function _xpcall(fn, handler, ...)
    return _handled(handler, pcall(fn, ...))
end

---@param output environment.Output
---@return fun(...)
local function _make_print(output)
    ---@param ... any
    return function(...)
        ---@type string[]
        local pieces = {}
        for i = 1, select("#", ...) do
            pieces[i] = tostring((select(i, ...)))
        end
        output(table.concat(pieces, "\t"))
    end
end

---@param data table<string, any> What the host shares with the script, as globals: not copied, so a table the host passes is the one the script reads and changes, and an entry replaces the standard one of its name
---@param output environment.Output
---@return table<string, any> The globals, a fresh table whose `_G` is itself
function environment.create(data, output)
    ---@type table<string, any>
    local globals = _G
    ---@type table<string, any>
    local env = {}
    for _, name in ipairs(BASE_FUNCTIONS) do
        env[name] = globals[name]
    end
    for library_name, names in pairs(LIBRARIES) do
        ---@type table<string, any>
        local library = globals[library_name]
        ---@type table<string, any>
        local copy = {}
        for _, name in ipairs(names) do
            copy[name] = library[name]
        end
        env[library_name] = copy
    end
    env.string.rep = _rep
    env.getmetatable = _getmetatable
    env.xpcall = _xpcall
    env.print = _make_print(output)
    env._VERSION = _VERSION
    env._G = env
    for name, value in pairs(data) do
        env[name] = value
    end
    return env
end

return environment

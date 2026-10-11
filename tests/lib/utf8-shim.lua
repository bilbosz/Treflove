---Minimal pure-Lua stand-in for the Lua 5.3 `utf8` library, which LÖVE bundles
---but plain LuaJIT lacks. Covers only what the code under test uses (`len`,
---`offset`, `codes`) and only for valid UTF-8 input. Installed by
---`tests/run.lua` when `require("utf8")` fails.
---@class Utf8Shim
local utf8_shim = {}

---@param s string
---@param i number
---@return boolean
local function _is_continuation(s, i)
    local byte = string.byte(s, i)
    return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

---@param s string
---@return number
function utf8_shim.len(s)
    local n = 0
    for i = 1, #s do
        if not _is_continuation(s, i) then
            n = n + 1
        end
    end
    return n
end

---Byte position where the `n`-th character (counted from byte `i`) starts;
---negative `n` counts backwards from `i` (default: end of string + 1).
---@param s string
---@param n number
---@param i number|nil
---@return number|nil
function utf8_shim.offset(s, n, i)
    i = i or (n >= 0 and 1 or #s + 1)
    if n == 0 then
        while i > 1 and _is_continuation(s, i) do
            i = i - 1
        end
        return i
    end
    assert(not _is_continuation(s, i), "initial position is a continuation byte")
    if n < 0 then
        while n < 0 and i > 1 do
            repeat
                i = i - 1
            until i <= 1 or not _is_continuation(s, i)
            n = n + 1
        end
    else
        n = n - 1
        while n > 0 and i <= #s do
            repeat
                i = i + 1
            until not _is_continuation(s, i)
            n = n - 1
        end
    end
    if n == 0 then
        return i
    end
    return nil
end

---@param s string
---@param i number Byte position of the current character, 0 before the first
---@return number|nil position
---@return number|nil code
local function _next_code(s, i)
    if i > 0 then
        repeat
            i = i + 1
        until not _is_continuation(s, i)
    else
        i = 1
    end
    if i > #s then
        return nil, nil
    end
    local b1, b2, b3, b4 = string.byte(s, i, i + 3)
    if b1 < 0x80 then
        return i, b1
    elseif b1 < 0xE0 then
        return i, (b1 - 0xC0) * 0x40 + (b2 - 0x80)
    elseif b1 < 0xF0 then
        return i, (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
    end
    return i, (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
end

---Iterate `(position, code)` over the characters of `s`.
---@param s string
---@return fun(s: string, i: number): number|nil, number|nil
---@return string
---@return number
function utf8_shim.codes(s)
    return _next_code, s, 0
end

return utf8_shim

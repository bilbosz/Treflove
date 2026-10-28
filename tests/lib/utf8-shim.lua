---`len`, `offset` and `codes` only; `len` validates, the others assume valid UTF-8.
---@class Utf8Shim
local utf8_shim = {}

---@param s string
---@param i number
---@return boolean
local function _is_continuation(s, i)
    local byte = string.byte(s, i)
    return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

---@param byte number
---@return number|nil The number of continuation bytes a lead byte announces; nil for a byte that leads nothing
local function _sequence_tail(byte)
    if byte < 0x80 then
        return 0
    elseif byte >= 0xC2 and byte < 0xE0 then
        return 1
    elseif byte >= 0xE0 and byte < 0xF0 then
        return 2
    elseif byte >= 0xF0 and byte < 0xF5 then
        return 3
    end
    return nil
end

---@param s string
---@return number|nil The number of characters, or nil for a string that is not UTF-8
---@return number|nil The byte position of the first invalid byte
function utf8_shim.len(s)
    local n, i = 0, 1
    while i <= #s do
        local tail = _sequence_tail(string.byte(s, i))
        if not tail then
            return nil, i
        end
        for j = i + 1, i + tail do
            if not _is_continuation(s, j) then
                return nil, i
            end
        end
        n = n + 1
        i = i + tail + 1
    end
    return n
end

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

---@param s string
---@return fun(s: string, i: number): number|nil, number|nil
---@return string
---@return number
function utf8_shim.codes(s)
    return _next_code, s, 0
end

return utf8_shim

---@class fonts
local fonts = {}

---@enum fonts.Kind
fonts.Kind = {
    DISPLAY = "fonts/OpenSans.ttf",
    USER_INPUT = "fonts/NotoSansMono.ttf"
}

---The size, in model units, the controls lay text out with
fonts.REFERENCE_SIZE = 80
fonts.MIN_PIXEL_SIZE = 4
fonts.MAX_PIXEL_SIZE = 256
---@type love.HintingMode
fonts.HINTING = "normal"

---@type table<fonts.Kind, table<number, love.Font>>
local cache = {}

---@param scale number Model units to screen pixels
---@return number An integer, clamped
function fonts.pixel_size(scale)
    local px = math.floor(fonts.REFERENCE_SIZE * scale + 0.5)
    return math.max(fonts.MIN_PIXEL_SIZE, math.min(fonts.MAX_PIXEL_SIZE, px))
end

---@param kind fonts.Kind
---@param pixel_size number An integer
---@return love.Font
function fonts.get(kind, pixel_size)
    local sizes = cache[kind]
    if not sizes then
        sizes = {}
        cache[kind] = sizes
    end
    local font = sizes[pixel_size]
    if not font then
        font = love.graphics.newFont(kind, pixel_size, fonts.HINTING)
        sizes[pixel_size] = font
    end
    return font
end

---@param kind fonts.Kind
---@return love.Font
function fonts.reference(kind)
    return fonts.get(kind, fonts.REFERENCE_SIZE)
end

function fonts.clear()
    cache = {}
end

return fonts

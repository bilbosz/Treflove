---@class fonts
local fonts = {}

---@enum fonts.Kind
fonts.Kind = {
    DISPLAY = "fonts/OpenSans.ttf",
    USER_INPUT = "fonts/NotoSansMono.ttf"
}

---@alias fonts.Face fonts.Kind|love.FileData A font file: one of the program's by its path, or the bytes of an asset

---The size, in model units, the controls lay text out with
fonts.REFERENCE_SIZE = 80
fonts.MIN_PIXEL_SIZE = 4
fonts.MAX_PIXEL_SIZE = 256
---@type love.HintingMode
fonts.HINTING = "normal"

---@type table<fonts.Face, table<number, love.Font>>
local cache = {}

---@param scale number Model units to screen pixels
---@return number An integer, clamped
function fonts.pixel_size(scale)
    local px = math.floor(fonts.REFERENCE_SIZE * scale + 0.5)
    return math.max(fonts.MIN_PIXEL_SIZE, math.min(fonts.MAX_PIXEL_SIZE, px))
end

---@param face fonts.Face
---@param pixel_size number An integer
---@return love.Font
function fonts.get(face, pixel_size)
    local sizes = cache[face]
    if not sizes then
        sizes = {}
        cache[face] = sizes
    end
    local font = sizes[pixel_size]
    if not font then
        -- the annotations lack the Data variant LÖVE documents for every
        -- constructor that takes a file name
        font = love.graphics.newFont(face --[[@as string]] , pixel_size, fonts.HINTING)
        sizes[pixel_size] = font
    end
    return font
end

---@param face fonts.Face
---@return love.Font
function fonts.reference(face)
    return fonts.get(face, fonts.REFERENCE_SIZE)
end

---@param face fonts.Face Its fonts, of every size, are made again on the next use
function fonts.forget(face)
    cache[face] = nil
end

function fonts.clear()
    cache = {}
end

return fonts

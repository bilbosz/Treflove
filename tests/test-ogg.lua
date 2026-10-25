local test = require("tests.lib.test")
local ogg = require("utils.ogg")

local BOS = 2
local THEORA_SERIAL = 0xDEADBEEF
local VORBIS_SERIAL = 7

---@param value number
---@param count number
---@return string
local function uint_le(value, count)
    ---@type string[]
    local bytes = {}
    for i = 1, count do
        bytes[i] = string.char(value % 256)
        value = math.floor(value / 256)
    end
    return table.concat(bytes)
end

---@param value number
---@param count number
---@return string
local function uint_be(value, count)
    return string.reverse(uint_le(value, count))
end

---@param serial number
---@param payload string One packet, ending on the page
---@param granule number|nil nil for -1
---@param header_type number|nil
---@return string
local function page(serial, payload, granule, header_type)
    local full_segments = math.floor(#payload / 255)
    local lacing = string.rep("\255", full_segments) .. string.char(#payload % 255)
    local granule_bytes = granule and uint_le(granule % 2 ^ 32, 4) .. uint_le(math.floor(granule / 2 ^ 32), 4) or string.rep("\255", 8)
    return "OggS" .. "\0" .. string.char(header_type or 0) .. granule_bytes .. uint_le(serial, 4) .. uint_le(0, 4) .. uint_le(0, 4) .. string.char(full_segments + 1) .. lacing .. payload
end

---@class TestTheoraIdent
---@field version number[]|nil {3, 2, 1} by default
---@field fps_numerator number|nil 25 by default
---@field fps_denominator number|nil 1 by default
---@field granule_shift number|nil 6 by default

---@param ident TestTheoraIdent|nil
---@return string
local function theora_ident(ident)
    ident = ident or {}
    local version = ident.version or {
        3,
        2,
        1
    }
    local packed = 63 * 1024 + (ident.granule_shift or 6) * 32
    return "\128theora" .. string.char(unpack(version)) .. uint_be(20, 2) .. uint_be(15, 2) .. uint_be(320, 3) .. uint_be(240, 3) .. "\0\0" .. uint_be(ident.fps_numerator or 25, 4) ..
               uint_be(ident.fps_denominator or 1, 4) .. uint_be(1, 3) .. uint_be(1, 3) .. "\0" .. uint_be(0, 3) .. uint_be(packed, 2)
end

---@return string
local function vorbis_ident()
    return "\1vorbis" .. uint_le(0, 4) .. "\2" .. uint_le(44100, 4) .. string.rep("\0", 12) .. "\184\1"
end

---@param keyframe number
---@param since_keyframe number
---@param shift number|nil 6 by default
---@return number
local function granule(keyframe, since_keyframe, shift)
    return keyframe * 2 ^ (shift or 6) + since_keyframe
end

---@param ident TestTheoraIdent|nil
---@return string
local function theora_headers(ident)
    return page(THEORA_SERIAL, theora_ident(ident), 0, BOS) .. page(THEORA_SERIAL, "\129theora comments", 0) .. page(THEORA_SERIAL, "\130theora setup", 0)
end

test.suite("ogg")

test.case("the Theora stream's identification header", function()
    local info = assert(ogg.find_theora(theora_headers({
        fps_numerator = 30000,
        fps_denominator = 1001,
        granule_shift = 9
    })))
    test.assert_eq(info.serial, THEORA_SERIAL)
    test.assert_deep_eq(info.version, {
        3,
        2,
        1
    })
    test.assert_eq(info.fps_numerator, 30000)
    test.assert_eq(info.fps_denominator, 1001)
    test.assert_eq(info.granule_shift, 9)
end)

test.case("the duration from the last Theora page, the Theora stream first or second", function()
    local data_pages = page(THEORA_SERIAL, "frames", granule(48, 2)) .. page(VORBIS_SERIAL, "samples", 44100) .. page(THEORA_SERIAL, "frames", granule(96, 4)) .. page(VORBIS_SERIAL, "samples", 999999)
    local theora_first = page(THEORA_SERIAL, theora_ident(), 0, BOS) .. page(VORBIS_SERIAL, vorbis_ident(), 0, BOS) .. data_pages
    local vorbis_first = page(VORBIS_SERIAL, vorbis_ident(), 0, BOS) .. page(THEORA_SERIAL, theora_ident(), 0, BOS) .. data_pages
    test.assert_eq(ogg.theora_duration(theora_first), 4)
    test.assert_eq(ogg.theora_duration(vorbis_first), 4)
    test.assert_eq(assert(ogg.find_theora(vorbis_first)).serial, THEORA_SERIAL)
end)

test.case("a last page on which no packet ends gives way to the one before", function()
    local bytes = theora_headers() .. page(THEORA_SERIAL, "frames", granule(72, 3)) .. page(THEORA_SERIAL, "part of a frame", nil)
    test.assert_eq(ogg.theora_duration(bytes), 3)
end)

test.case("version 3.2.0 stored the last frame's index, one less than the count", function()
    local bytes = theora_headers({
        version = {
            3,
            2,
            0
        }
    }) .. page(THEORA_SERIAL, "frames", granule(96, 3))
    test.assert_eq(ogg.theora_duration(bytes), 4)
end)

test.case("a granule position beyond 32 bits", function()
    local bytes = theora_headers({
        granule_shift = 31,
        fps_numerator = 1
    }) .. page(THEORA_SERIAL, "frames", granule(5, 7, 31))
    test.assert_eq(ogg.theora_duration(bytes), 12)
end)

test.case("a page inside another page's payload is not read", function()
    local hidden = page(THEORA_SERIAL, "frames", granule(1000, 0))
    local bytes = theora_headers() .. page(VORBIS_SERIAL, vorbis_ident(), 0, BOS) .. page(THEORA_SERIAL, "frames", granule(96, 4)) .. page(VORBIS_SERIAL, "samples" .. hidden, 88200)
    test.assert_eq(ogg.theora_duration(bytes), 4)
end)

test.case("a page cut short at the end of the file is not read", function()
    local whole = theora_headers() .. page(THEORA_SERIAL, "frames", granule(96, 4))
    local last = page(THEORA_SERIAL, "frames", granule(1000, 0))
    test.assert_eq(ogg.theora_duration(whole .. string.sub(last, 1, #last - 1)), 4)
end)

test.case("an identification header after the streams' first pages is not one", function()
    local bytes = page(VORBIS_SERIAL, vorbis_ident(), 0, BOS) .. page(THEORA_SERIAL, theora_ident(), 0) .. page(THEORA_SERIAL, "frames", granule(96, 4))
    test.assert_eq(ogg.find_theora(bytes), nil)
end)

test.case("no Theora stream, no duration", function()
    local vorbis = page(VORBIS_SERIAL, vorbis_ident(), 0, BOS) .. page(VORBIS_SERIAL, "samples", 44100)
    test.assert_eq(ogg.find_theora(vorbis), nil)
    test.assert_eq(ogg.theora_duration(vorbis), nil)
    test.assert_eq(ogg.find_theora("\137PNG\r\n\26\n"), nil)
    test.assert_eq(ogg.theora_duration(""), nil)
end)

test.case("a frame rate with a zero is no Theora stream", function()
    test.assert_eq(ogg.find_theora(theora_headers({
        fps_numerator = 0
    })), nil)
    test.assert_eq(ogg.find_theora(theora_headers({
        fps_denominator = 0
    })), nil)
end)

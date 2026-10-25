---@class ogg
local ogg = {}

---@class TheoraInfo
---@field serial number The stream's serial number as the page headers carry it
---@field version number[] {VMAJ, VMIN, VREV}
---@field fps_numerator number FRN
---@field fps_denominator number FRD
---@field granule_shift number KFGSHIFT

---@class ogg.Page
---@field header_type number
---@field granule number|nil nil when negative: -1 says no packet ends on the page
---@field serial number
---@field payload_at number Index of the payload's first byte
---@field next_at number Index just past the payload, where the next page starts

local CAPTURE_PATTERN = "OggS"
local PAGE_HEADER_SIZE = 27
local SUPPORTED_PAGE_VERSION = 0
local BEGINNING_OF_STREAM_FLAG = 2
local THEORA_SIGNATURE = "\128theora"
local THEORA_IDENT_SIZE = 42
---@type number[] The first version whose granule position counts the frames instead of indexing the last one
local FRAME_COUNTING_VERSION = {
    3,
    2,
    1
}

---@param bytes string
---@param at number
---@param count number
---@return number
local function _read_uint_le(bytes, at, count)
    local value = 0
    for i = count - 1, 0, -1 do
        value = value * 256 + string.byte(bytes, at + i)
    end
    return value
end

---@param bytes string
---@param at number
---@param count number
---@return number
local function _read_uint_be(bytes, at, count)
    local value = 0
    for i = 0, count - 1 do
        value = value * 256 + string.byte(bytes, at + i)
    end
    return value
end

---@param flags number
---@param flag number A power of two
---@return boolean
local function _has_flag(flags, flag)
    return math.floor(flags / flag) % 2 == 1
end

---@param bytes string
---@param at number
---@return ogg.Page|nil page nil unless a whole page of the supported version starts at `at`
local function _read_page(bytes, at)
    if string.sub(bytes, at, at + #CAPTURE_PATTERN - 1) ~= CAPTURE_PATTERN or at + PAGE_HEADER_SIZE - 1 > #bytes then
        return nil
    end
    if string.byte(bytes, at + 4) ~= SUPPORTED_PAGE_VERSION then
        return nil
    end
    local segments_at = at + PAGE_HEADER_SIZE
    local payload_at = segments_at + string.byte(bytes, at + 26)
    if payload_at - 1 > #bytes then
        return nil
    end
    local payload_size = 0
    for i = segments_at, payload_at - 1 do
        payload_size = payload_size + string.byte(bytes, i)
    end
    local next_at = payload_at + payload_size
    if next_at - 1 > #bytes then
        return nil
    end
    local granule_low = _read_uint_le(bytes, at + 6, 4)
    local granule_high = _read_uint_le(bytes, at + 10, 4)
    return {
        header_type = string.byte(bytes, at + 5),
        granule = granule_high < 2 ^ 31 and granule_low + granule_high * 2 ^ 32 or nil,
        serial = _read_uint_le(bytes, at + 14, 4),
        payload_at = payload_at,
        next_at = next_at
    }
end

---@param bytes string
---@param page ogg.Page
---@return TheoraInfo|nil
local function _read_theora_ident(bytes, page)
    local at = page.payload_at
    if page.next_at - at < THEORA_IDENT_SIZE or string.sub(bytes, at, at + #THEORA_SIGNATURE - 1) ~= THEORA_SIGNATURE then
        return nil
    end
    local fps_numerator = _read_uint_be(bytes, at + 22, 4)
    local fps_denominator = _read_uint_be(bytes, at + 26, 4)
    if fps_numerator == 0 or fps_denominator == 0 then
        return nil
    end
    local packed_high, packed_low = string.byte(bytes, at + 40, at + 41)
    return {
        serial = page.serial,
        version = {
            string.byte(bytes, at + 7, at + 9)
        },
        fps_numerator = fps_numerator,
        fps_denominator = fps_denominator,
        granule_shift = (packed_high % 4) * 8 + math.floor(packed_low / 32)
    }
end

---@param version number[]
---@return boolean
local function _counts_frames(version)
    for i, part in ipairs(FRAME_COUNTING_VERSION) do
        if version[i] ~= part then
            return version[i] > part
        end
    end
    return true
end

---@param granule number
---@param info TheoraInfo
---@return number
local function _frame_count(granule, info)
    local keyframe_scale = 2 ^ info.granule_shift
    local keyframe = math.floor(granule / keyframe_scale)
    local frames = keyframe + (granule - keyframe * keyframe_scale)
    if not _counts_frames(info.version) then
        frames = frames + 1
    end
    return frames
end

---The Theora stream among the streams that begin the file
---@param bytes string An Ogg file
---@return TheoraInfo|nil
function ogg.find_theora(bytes)
    local page = _read_page(bytes, 1)
    while page and _has_flag(page.header_type, BEGINNING_OF_STREAM_FLAG) do
        local info = _read_theora_ident(bytes, page)
        if info then
            return info
        end
        page = _read_page(bytes, page.next_at)
    end
    return nil
end

---@param bytes string An Ogg file, walked page by page from its start up to its last whole page
---@return number|nil seconds nil without a Theora stream
function ogg.theora_duration(bytes)
    local info = ogg.find_theora(bytes)
    if not info then
        return nil
    end
    ---@type number|nil
    local granule = nil
    local page = _read_page(bytes, 1)
    while page do
        if page.serial == info.serial and page.granule then
            granule = page.granule
        end
        page = _read_page(bytes, page.next_at)
    end
    if not granule then
        return nil
    end
    return _frame_count(granule, info) * info.fps_denominator / info.fps_numerator
end

return ogg

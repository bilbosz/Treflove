local test = require("tests.lib.test")
local media = require("utils.media")

local PNG = "\137PNG\r\n\26\n"
local TTF = "\0\1\0\0"
local NOT_AUDIO = "not audio"
local SOUND_VIDEO_PATH = "assets/sound.ogv"
local SILENT_VIDEO_PATH = "assets/silent.ogv"
local BROKEN_VIDEO_PATH = "assets/broken.ogv"

---@param serial number
---@param payload string At most 254 bytes: one segment
---@param granule number Below 2^16
---@param header_type number
---@return string
local function ogg_page(serial, payload, granule, header_type)
    return "OggS\0" .. string.char(header_type, granule % 256, math.floor(granule / 256), 0, 0, 0, 0, 0, 0, serial, 0, 0, 0) .. string.rep("\0", 8) .. string.char(1, #payload) .. payload
end

---@return string
local function theora_ident_page()
    local frame_rate = "\0\0\0\25\0\0\0\1"
    local granule_shift_6 = "\0\192"
    local payload = "\128theora\3\2\1" .. string.rep("\0", 12) .. frame_rate .. string.rep("\0", 10) .. granule_shift_6
    return ogg_page(1, payload, 0, 2)
end

---@return string
local function vorbis_ident_page()
    return ogg_page(2, "\1vorbis" .. string.rep("\0", 23), 0, 2)
end

---@param bytes string
---@return TestFileData
local function make_file_data(bytes)
    ---@class TestFileData: love.FileData
    ---@field bytes string
    local data = {
        bytes = bytes
    }

    ---@return string
    function data:getString()
        return self.bytes
    end

    return data
end

---@class TestMediaFake
---@field kind string What LÖVE would have made
---@field source string|TestFileData What it was made of

---@class TestVideoCall
---@field path string
---@field settings {audio: boolean}|nil

---@class TestMediaLog
---@field video_calls TestVideoCall[]
---@field audio_calls number
---@field made TestMediaFake|nil The last medium a fake made

---@class TestMediaLove
---@field graphics love.graphics|nil
---@field audio love.audio|nil

---@type TestMediaLove|nil
local saved = nil

---@param bytes string
---@param prefix string
---@return boolean
local function starts_with(bytes, prefix)
    return string.sub(bytes, 1, #prefix) == prefix
end

---@return TestMediaLog
local function install_fakes()
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    saved = {
        graphics = love.graphics,
        audio = love.audio
    }
    ---@type TestMediaLog
    local log = {
        video_calls = {},
        audio_calls = 0
    }
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        newImage = function(data)
            assert(starts_with(data:getString(), PNG), "not an image")
            log.made = {
                kind = "image",
                source = data,
                setFilter = function()
                end,
                setMipmapFilter = function()
                end
            }
            return log.made
        end,
        newFont = function(data)
            assert(starts_with(data:getString(), TTF), "not a font")
            log.made = {
                kind = "font",
                source = data
            }
            return log.made
        end,
        newVideo = function(path, settings)
            table.insert(log.video_calls, {
                path = path,
                settings = settings
            })
            assert(path ~= BROKEN_VIDEO_PATH, "Could not open the file")
            assert(path == SOUND_VIDEO_PATH or not (settings and settings.audio), "Video had no audio track")
            log.made = {
                kind = "video",
                source = path
            }
            return log.made
        end
    }
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.audio = {
        newSource = function(data)
            log.audio_calls = log.audio_calls + 1
            assert(not starts_with(data:getString(), NOT_AUDIO), "not audio")
            log.made = {
                kind = "audio",
                source = data
            }
            return log.made
        end
    }
    return log
end

local function restore_love()
    local previous = assert(saved)
    love.graphics = previous.graphics
    love.audio = previous.audio
    saved = nil
end

---@param bytes string
---@param path string|nil
---@return media.Type|nil, LoveMedium
local function detect(bytes, path)
    return media.get_type_and_medium(make_file_data(bytes), path)
end

test.suite("media")

test.case("a PNG is an image", function()
    local log = install_fakes()
    local media_type, medium = detect(PNG .. "pixels", nil)
    test.assert_eq(media_type, media.Type.IMAGE)
    test.assert_eq(medium, log.made)
    test.assert_eq(assert(log.made).kind, "image")
    restore_love()
end)

test.case("a font is a font although LÖVE's decoders would take it for a sound", function()
    local log = install_fakes()
    local media_type, medium = detect(TTF .. "glyphs", nil)
    test.assert_eq(media_type, media.Type.FONT)
    test.assert_eq(medium, log.made)
    test.assert_eq(assert(log.made).kind, "font")
    test.assert_eq(log.audio_calls, 0)
    restore_love()
end)

test.case("a video with a sound track opens with its sound", function()
    local log = install_fakes()
    local media_type, medium = detect(theora_ident_page() .. vorbis_ident_page(), SOUND_VIDEO_PATH)
    test.assert_eq(media_type, media.Type.VIDEO)
    test.assert_eq(medium, log.made)
    test.assert_deep_eq(log.video_calls, {
        {
            path = SOUND_VIDEO_PATH,
            settings = {
                audio = true
            }
        }
    })
    restore_love()
end)

test.case("a silent video opens without sound once the sound is refused", function()
    local log = install_fakes()
    local media_type, medium = detect(theora_ident_page(), SILENT_VIDEO_PATH)
    test.assert_eq(media_type, media.Type.VIDEO)
    test.assert_eq(medium, log.made)
    test.assert_deep_eq(log.video_calls, {
        {
            path = SILENT_VIDEO_PATH,
            settings = {
                audio = true
            }
        },
        {
            path = SILENT_VIDEO_PATH
        }
    })
    restore_love()
end)

test.case("a video LÖVE cannot open here is still a video, without a medium", function()
    local log = install_fakes()
    test.assert_deep_eq({
        detect(theora_ident_page(), nil)
    }, {
        media.Type.VIDEO
    }, "a dropped file")
    test.assert_eq(#log.video_calls, 0)
    test.assert_deep_eq({
        detect(theora_ident_page(), BROKEN_VIDEO_PATH)
    }, {
        media.Type.VIDEO
    }, "a file LÖVE refuses")
    test.assert_eq(#log.video_calls, 2)
    restore_love()
end)

test.case("a video with a Vorbis track is not audio", function()
    local log = install_fakes()
    local media_type = detect(vorbis_ident_page() .. theora_ident_page(), nil)
    test.assert_eq(media_type, media.Type.VIDEO)
    test.assert_eq(log.audio_calls, 0)
    restore_love()
end)

test.case("a Vorbis file is audio", function()
    local log = install_fakes()
    local media_type, medium = detect(vorbis_ident_page() .. ogg_page(2, "samples", 100, 0), "assets/tone.ogg")
    test.assert_eq(media_type, media.Type.AUDIO)
    test.assert_eq(medium, log.made)
    test.assert_eq(assert(log.made).kind, "audio")
    restore_love()
end)

test.case("bytes of no type give no type and no medium", function()
    install_fakes()
    test.assert_deep_eq({
        detect(NOT_AUDIO, nil)
    }, {})
    restore_love()
end)

test.case("a video's duration is read from its pages", function()
    local frames_page = ogg_page(1, "frames", 6 * 64 + 4, 0)
    test.assert_eq(media.video_duration(make_file_data(theora_ident_page() .. vorbis_ident_page() .. frames_page)), 0.4)
    test.assert_eq(media.video_duration(make_file_data(vorbis_ident_page() .. ogg_page(2, "samples", 100, 0))), nil)
end)

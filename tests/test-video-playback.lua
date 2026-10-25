local test = require("tests.lib.test")
local VideoPlayback = require("ui.video-playback")

---@param duration number
---@return TestVideoPlaybackSource
local function make_source(duration)
    ---@class TestVideoPlaybackSource: love.Source
    local source = {}

    ---@return number
    function source:getDuration()
        return duration
    end

    return source
end

---@param source love.Source|nil The sound of the video
---@return TestVideoPlaybackVideo
local function make_video(source)
    ---@class TestVideoPlaybackVideo: love.Video
    ---@field log string[] Every call, in order
    ---@field position number
    ---@field playing boolean
    local video = {
        log = {},
        position = 0,
        playing = false
    }

    function video:play()
        table.insert(self.log, "play")
        self.playing = true
    end

    function video:pause()
        table.insert(self.log, "pause")
        self.playing = false
    end

    function video:rewind()
        table.insert(self.log, "rewind")
        self.position = 0
    end

    ---@param offset number
    function video:seek(offset)
        table.insert(self.log, "seek " .. offset)
        self.position = offset
    end

    ---@return number
    function video:tell()
        return self.position
    end

    ---@return boolean
    function video:isPlaying()
        return self.playing
    end

    ---@return love.Source|nil
    function video:getSource()
        return source
    end

    return video
end

test.suite("VideoPlayback")

test.case("plays, pauses and seeks its video; a stop pauses and rewinds it", function()
    local video = make_video(nil)
    local playback = VideoPlayback(video, 3)
    playback:play()
    test.assert_true(playback:is_playing())
    playback:seek(2)
    test.assert_eq(playback:tell(), 2)
    playback:stop()
    test.assert_false(playback:is_playing())
    test.assert_eq(playback:tell(), 0)
    test.assert_deep_eq(video.log, {
        "play",
        "seek 2",
        "pause",
        "rewind"
    })
end)

test.case("the duration is the one given, else the sound's, else unknown", function()
    test.assert_eq(VideoPlayback(make_video(make_source(4.5)), 3):get_duration(), 3, "the file's duration first")
    test.assert_eq(VideoPlayback(make_video(make_source(4.5)), nil):get_duration(), 4.5, "the sound's without it")
    test.assert_eq(VideoPlayback(make_video(make_source(-1)), nil):get_duration(), nil, "a sound of unknown length")
    test.assert_eq(VideoPlayback(make_video(nil), nil):get_duration(), nil, "a silent video")
end)

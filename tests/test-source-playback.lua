local test = require("tests.lib.test")
local SourcePlayback = require("ui.source-playback")

---@param duration number What LÖVE reports, -1 when it cannot tell
---@return TestSourcePlaybackSource
local function make_source(duration)
    ---@class TestSourcePlaybackSource: love.Source
    ---@field log string[] Every call, in order
    ---@field position number
    ---@field playing boolean
    local source = {
        log = {},
        position = 0,
        playing = false
    }

    ---@return boolean
    function source:play()
        table.insert(self.log, "play")
        self.playing = true
        return true
    end

    function source:pause()
        table.insert(self.log, "pause")
        self.playing = false
    end

    function source:stop()
        table.insert(self.log, "stop")
        self.playing = false
        self.position = 0
    end

    ---@param offset number
    function source:seek(offset)
        table.insert(self.log, "seek " .. offset)
        self.position = offset
    end

    ---@return number
    function source:tell()
        return self.position
    end

    ---@return boolean
    function source:isPlaying()
        return self.playing
    end

    ---@return number
    function source:getDuration()
        return duration
    end

    return source
end

test.suite("SourcePlayback")

test.case("plays, pauses, stops and seeks its source", function()
    local source = make_source(2.5)
    local playback = SourcePlayback(source)
    test.assert_false(playback:is_playing())

    playback:play()
    test.assert_true(playback:is_playing())
    playback:seek(1.25)
    test.assert_eq(playback:tell(), 1.25)
    playback:pause()
    test.assert_false(playback:is_playing())
    test.assert_eq(playback:tell(), 1.25, "a pause keeps the position")
    playback:stop()
    test.assert_eq(playback:tell(), 0, "a stop goes back to the start")
    test.assert_deep_eq(source.log, {
        "play",
        "seek 1.25",
        "pause",
        "stop"
    })
end)

test.case("the duration is the source's, nil when LÖVE cannot tell it", function()
    test.assert_eq(SourcePlayback(make_source(2.5)):get_duration(), 2.5)
    test.assert_eq(SourcePlayback(make_source(-1)):get_duration(), nil)
end)

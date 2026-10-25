local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Control = require("controls.control")
local FormScreen = require("ui.form-screen")
local MediaPlayer = require("ui.media-player")
local Playback = require("ui.playback")

local LEFT = Consts.LEFT_MOUSE_BUTTON
local PADDING, SCALE = Consts.PADDING, Consts.PANEL_FIELD_SCALE

---@class TestPlayback: Playback
---@field log string[] Every call that changes the playback, in order
---@field position number
---@field playing boolean
---@field duration number|nil
---@field rest_at_end number Where the position rests once the playback ran to its end: 0, as a source's, or beyond the duration, as a silent video's
local TestPlayback = class("TestPlayback", Playback)

---@param duration number|nil
function TestPlayback:init(duration)
    self.log = {}
    self.position = 0
    self.playing = false
    self.duration = duration
    self.rest_at_end = 0
end

function TestPlayback:play()
    table.insert(self.log, "play")
    self.playing = true
end

function TestPlayback:pause()
    table.insert(self.log, "pause")
    self.playing = false
end

function TestPlayback:stop()
    table.insert(self.log, "stop")
    self.playing = false
    self.position = 0
end

---@param seconds number
function TestPlayback:seek(seconds)
    table.insert(self.log, "seek " .. seconds)
    self.position = seconds
end

---@return number
function TestPlayback:tell()
    return self.position
end

---@return boolean
function TestPlayback:is_playing()
    return self.playing
end

---@return number|nil
function TestPlayback:get_duration()
    return self.duration
end

---@param dt number
function TestPlayback:advance(dt)
    if not self.playing then
        return
    end
    self.position = self.position + dt
    if self.duration and self.position >= self.duration then
        self.playing = false
        self.position = self.rest_at_end
    end
end

---@class TestMediaPlayerSetup
---@field app AppMock
---@field root Control
---@field form FormScreen
---@field playback TestPlayback
---@field player MediaPlayer 400 wide at the root's origin

---@param duration number|nil
---@return TestMediaPlayerSetup
local function setup(duration)
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local root = Control()
    app_mock.root = root
    local form = FormScreen()
    local playback = TestPlayback(duration)
    return {
        app = app_mock,
        root = root,
        form = form,
        playback = playback,
        player = MediaPlayer(root, form, 400, playback)
    }
end

---@param s TestMediaPlayerSetup
local function finish(s)
    lifetime.destroy(s.form)
    lifetime.destroy(s.root)
end

---@param s TestMediaPlayerSetup
---@param dt number
local function frame(s, dt)
    s.playback:advance(dt)
    s.app.update_event:trigger(dt)
end

---@param player MediaPlayer
---@return TextButton
local function play_button(player)
    ---@diagnostic disable-next-line: invisible
    return player._play_button
end

---@param player MediaPlayer
---@return TextButton
local function stop_button(player)
    ---@diagnostic disable-next-line: invisible
    return player._stop_button
end

---@param player MediaPlayer
---@return Text
local function time_text(player)
    ---@diagnostic disable-next-line: invisible
    return player._time
end

---@param player MediaPlayer
---@return SeekBar
local function seek_bar(player)
    ---@diagnostic disable-next-line: invisible
    return player._seek_bar
end

test.suite("MediaPlayer")

test.case("lays out its buttons and time over a background, the seek bar below them", function()
    local s = setup(65)
    local row_h = 20 * SCALE
    local bar = seek_bar(s.player)
    local _, bar_h = bar:get_size()
    test.assert_deep_eq({
        s.player:get_size()
    }, {
        400,
        3 * PADDING + row_h + bar_h
    })
    local background = s.player:get_children()[1]
    test.assert_deep_eq({
        background:get_size()
    }, {
        s.player:get_size()
    }, "the background covers the player")
    test.assert_deep_eq({
        play_button(s.player):get_position()
    }, {
        PADDING,
        PADDING
    })
    test.assert_deep_eq({
        stop_button(s.player):get_position()
    }, {
        2 * PADDING + 50 * SCALE,
        PADDING
    }, "past the wider caption, Pause")
    local time = time_text(s.player)
    local time_x = time:get_position()
    test.assert_near(time_x + time:get_outer_size(), 400 - PADDING, 1e-9, "the time is right-aligned")
    test.assert_deep_eq({
        bar:get_position()
    }, {
        PADDING,
        2 * PADDING + row_h
    })
    test.assert_eq((bar:get_size()), 400 - 2 * PADDING)
    finish(s)
end)

test.case("Play and Pause toggle the playback and the caption follows it", function()
    local s = setup(65)
    local button = play_button(s.player)
    test.assert_eq(button:get_text(), "Play")
    button:on_click()
    test.assert_true(s.playback.playing)
    test.assert_eq(button:get_text(), "Pause")
    button:on_click()
    test.assert_false(s.playback.playing)
    test.assert_eq(button:get_text(), "Play")

    s.playback.playing = true
    frame(s, 0)
    test.assert_eq(button:get_text(), "Pause", "a playback started elsewhere shows on the next frame")
    test.assert_deep_eq(s.playback.log, {
        "play",
        "pause"
    })
    finish(s)
end)

test.case("Stop goes back to the start and stops playing", function()
    local s = setup(65)
    play_button(s.player):on_click()
    frame(s, 10)
    stop_button(s.player):on_click()
    test.assert_false(s.playback.playing)
    test.assert_eq(s.playback.position, 0)
    test.assert_eq(play_button(s.player):get_text(), "Play")
    test.assert_eq(time_text(s.player):get_text(), "0:00 / 1:05")
    test.assert_deep_eq(s.playback.log, {
        "play",
        "stop"
    })
    finish(s)
end)

test.case("the time shows the position and the duration, set again only when its text changes", function()
    local s = setup(65)
    local time = time_text(s.player)
    test.assert_eq(time:get_text(), "0:00 / 1:05")
    local sets = 0
    time.set_text = function(...)
        sets = sets + 1
        return getmetatable(time).__index.set_text(...)
    end

    play_button(s.player):on_click()
    frame(s, 0.4)
    frame(s, 0.4)
    test.assert_eq(sets, 0, "still under a second")
    frame(s, 0.4)
    test.assert_eq(time:get_text(), "0:01 / 1:05")
    test.assert_eq(sets, 1)
    frame(s, 61)
    test.assert_eq(time:get_text(), "1:02 / 1:05")
    local time_x = time:get_position()
    test.assert_near(time_x + time:get_outer_size(), 400 - PADDING, 1e-9, "still right-aligned")
    finish(s)
end)

test.case("an hour or more shows the hours of both", function()
    local s = setup(3725)
    test.assert_eq(time_text(s.player):get_text(), "0:00:00 / 1:02:05")
    finish(s)
end)

test.case("the seek bar follows the position", function()
    local s = setup(60)
    local bar = seek_bar(s.player)
    test.assert_eq(bar:get_fraction(), 0)
    play_button(s.player):on_click()
    frame(s, 15)
    test.assert_near(bar:get_fraction(), 0.25)
    finish(s)
end)

test.case("a playback that ends by itself shows Play, the full time and a full bar", function()
    local s = setup(3)
    s.playback.rest_at_end = 3.23
    play_button(s.player):on_click()
    frame(s, 4)
    test.assert_false(s.playback.playing)
    test.assert_eq(play_button(s.player):get_text(), "Play")
    test.assert_eq(time_text(s.player):get_text(), "0:03 / 0:03", "the position beyond the end is clamped")
    test.assert_eq(seek_bar(s.player):get_fraction(), 1)
    finish(s)
end)

test.case("Play at the end starts over; elsewhere it resumes", function()
    local s = setup(3)
    s.playback.rest_at_end = 3.23
    local button = play_button(s.player)
    button:on_click()
    frame(s, 4)
    button:on_click()
    test.assert_deep_eq(s.playback.log, {
        "play",
        "stop",
        "play"
    })
    test.assert_eq(s.playback.position, 0)
    frame(s, 1)
    button:on_click()
    button:on_click()
    test.assert_eq(s.playback.position, 1, "a pause and a play resume where it was")
    test.assert_deep_eq(s.playback.log, {
        "play",
        "stop",
        "play",
        "pause",
        "play"
    })
    finish(s)
end)

test.case("an unknown duration shows the position alone and cannot be sought", function()
    local s = setup(nil)
    local time = time_text(s.player)
    test.assert_eq(time:get_text(), "0:00")
    test.assert_false(seek_bar(s.player):is_seekable())
    play_button(s.player):on_click()
    frame(s, 75)
    test.assert_eq(time:get_text(), "1:15")
    test.assert_true(s.playback.playing, "nothing ends it")
    finish(s)
end)

test.case("the seek bar seeks the playback, and a drag holds the bar against the position", function()
    local s = setup(60)
    local bar = seek_bar(s.player)
    local manager = s.app.pointer_event_manager
    local bar_w, bar_h = bar:get_size()
    local x, y = bar:transform_to_global(bar_w * 0.5, bar_h * 0.5)
    play_button(s.player):on_click()

    manager:dispatch_pointer_down(x, y, LEFT)
    test.assert_deep_eq(s.playback.log, {
        "play",
        "seek 30"
    })
    test.assert_eq(time_text(s.player):get_text(), "0:30 / 1:00", "shown at once")
    frame(s, 6)
    test.assert_near(bar:get_fraction(), 0.5, 1e-9, "the dragged bar stays under the pointer")
    manager:dispatch_pointer_up(x, y, LEFT)
    frame(s, 0)
    test.assert_near(bar:get_fraction(), 0.6, 1e-9, "released, it follows the position again")
    finish(s)
end)

test.case("destroying the player stops the playback, unlinks its buttons and ends its frame updates", function()
    local s = setup(60)
    s.form:show()
    play_button(s.player):on_click()
    lifetime.destroy(s.player)
    test.assert_deep_eq(s.playback.log, {
        "play",
        "stop"
    })
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(s.form._inputs, {}, "the buttons left the form")
    test.assert_eq(s.app.update_event:get_handler(s.player), nil)
    test.assert_deep_eq(s.root:get_children(), {
        s.form:get_control()
    }, "the player left the tree")
    finish(s)
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local FormScreen = require("ui.form-screen")
local MediaPlayer = require("ui.media-player")
local PreviewArea = require("game.assets.preview-area.preview-area")
local PreviewVideoArea = require("game.assets.preview-area.preview-video-area")
local Video = require("controls.video")
local media = require("utils.media")

local AREA_W, AREA_H = 400, 300

---@return TestPreviewVideoFake
local function make_video()
    ---@class TestPreviewVideoFake: love.Video
    ---@field log string[] Every call that changes the playback, in order
    ---@field playing boolean
    local video = {
        log = {},
        playing = false
    }

    ---@return number, number
    function video:getDimensions()
        return 160, 90
    end

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
    end

    ---@return number
    function video:tell()
        return 0
    end

    ---@return boolean
    function video:isPlaying()
        return self.playing
    end

    ---@return love.Source|nil
    function video:getSource()
        return nil
    end

    return video
end

---@class TestPreviewVideoSetup
---@field form FormScreen
---@field area PreviewArea 400 x 300
---@field video TestPreviewVideoFake
---@field data love.FileData
---@field video_duration fun(data: media.Source): number|nil The media module's own

---@return TestPreviewVideoSetup
local function setup()
    mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local form = FormScreen()
    ---@type FileDropTarget
    local target = {
        set_file = function()
        end
    }
    ---@class TestPreviewVideoData: love.FileData
    local data = {}
    local video_duration = media.video_duration
    ---@param source media.Source
    ---@return number|nil
    media.video_duration = function(source)
        return source == data and 3 or nil
    end
    local area = PreviewArea(form:get_control(), AREA_W, AREA_H, target, form)
    return {
        form = form,
        area = area,
        video = make_video(),
        data = data,
        video_duration = video_duration
    }
end

---@param s TestPreviewVideoSetup
local function finish(s)
    media.video_duration = s.video_duration
    lifetime.destroy(s.form)
end

---@param s TestPreviewVideoSetup
---@return PreviewVideoArea
local function preview(s)
    ---@diagnostic disable-next-line: invisible
    local component = assert(s.area._preview)
    assert(is_instance_of(component, PreviewVideoArea))
    ---@cast component PreviewVideoArea
    return component
end

---@param component Control
---@param cls Class
---@return Control
local function child_of_class(component, cls)
    for _, child in ipairs(component:get_children()) do
        if is_instance_of(child, cls) then
            return child
        end
    end
    error("no such child")
end

---@param component Control
---@return MediaPlayer
local function player_of(component)
    local player = child_of_class(component, MediaPlayer)
    ---@cast player MediaPlayer
    return player
end

test.suite("PreviewVideoArea")

test.case("fits the video above the player, which spans the bottom of the area", function()
    local s = setup()
    s.area:show_medium(media.Type.VIDEO, s.video, s.data)
    local component = preview(s)
    local player = player_of(component)
    local video = child_of_class(component, Video)

    local player_w, player_h = player:get_size()
    test.assert_eq(player_w, AREA_W)
    test.assert_deep_eq({
        player:get_position()
    }, {
        -AREA_W * 0.5,
        AREA_H * 0.5 - player_h
    })

    local x, y, w, h = video:get_position_and_outer_size()
    local free_h = AREA_H - player_h - 2 * Consts.PADDING
    test.assert_near(h, free_h, 1e-9, "the height limits the fit")
    test.assert_near(w, 160 * free_h / 90)
    test.assert_near(x + w * 0.5, 0, 1e-9, "centered across")
    test.assert_near(y + h * 0.5, -player_h * 0.5, 1e-9, "centered above the player")
    finish(s)
end)

test.case("the player plays the video for the duration the file tells", function()
    local s = setup()
    s.area:show_medium(media.Type.VIDEO, s.video, s.data)
    local player = player_of(preview(s))
    ---@diagnostic disable-next-line: invisible
    local playback = player._playback
    test.assert_eq(playback:get_duration(), 3)
    ---@diagnostic disable-next-line: invisible
    player._play_button:on_click()
    test.assert_deep_eq(s.video.log, {
        "play"
    })
    finish(s)
end)

test.case("a reset of the area destroys the preview and stops the video", function()
    local s = setup()
    s.form:show()
    s.area:show_medium(media.Type.VIDEO, s.video, s.data)
    local component = preview(s)
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(#s.form._inputs, 2, "Play and Stop")
    s.area:reset()
    test.assert_false(lifetime.alive(component))
    test.assert_deep_eq(s.video.log, {
        "pause",
        "rewind"
    })
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(s.form._inputs, {}, "the buttons left the form")
    test.assert_deep_eq(s.area.content_parent:get_children(), {})
    finish(s)
end)

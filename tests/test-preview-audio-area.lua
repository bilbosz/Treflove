local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local images = require("graphics.images")
local Consts = require("app.consts")
local FormScreen = require("ui.form-screen")
local Image = require("controls.image")
local MediaPlayer = require("ui.media-player")
local PreviewArea = require("game.assets.preview-area.preview-area")
local PreviewAudioArea = require("game.assets.preview-area.preview-audio-area")
local media = require("utils.media")

local AREA_W, AREA_H = 400, 300

---@return TestPreviewAudioSource
local function make_source()
    ---@class TestPreviewAudioSource: love.Source
    ---@field log string[] Every call that changes the playback, in order
    ---@field playing boolean
    local source = {
        log = {},
        playing = false
    }

    ---@return boolean
    function source:play()
        table.insert(self.log, "play")
        self.playing = true
        return true
    end

    function source:stop()
        table.insert(self.log, "stop")
        self.playing = false
    end

    ---@return number
    function source:tell()
        return 0
    end

    ---@return boolean
    function source:isPlaying()
        return self.playing
    end

    ---@return number
    function source:getDuration()
        return 2.5
    end

    return source
end

---@class TestPreviewAudioSetup
---@field form FormScreen
---@field area PreviewArea 400 x 300
---@field source TestPreviewAudioSource
---@field data love.FileData
---@field previous_filesystem love.filesystem|nil

---@return TestPreviewAudioSetup
local function setup()
    mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local previous = mocks.install_love_filesystem({})
    images.clear()
    local form = FormScreen()
    ---@type FileDropTarget
    local target = {
        set_file = function()
        end
    }
    ---@class TestPreviewAudioData: love.FileData
    local data = {}
    return {
        form = form,
        area = PreviewArea(form:get_control(), AREA_W, AREA_H, target, form),
        source = make_source(),
        data = data,
        previous_filesystem = previous
    }
end

---@param s TestPreviewAudioSetup
local function finish(s)
    lifetime.destroy(s.form)
    mocks.restore_love_filesystem(s.previous_filesystem)
end

---@param s TestPreviewAudioSetup
---@return PreviewAudioArea
local function preview(s)
    ---@diagnostic disable-next-line: invisible
    local component = assert(s.area._preview)
    assert(is_instance_of(component, PreviewAudioArea))
    ---@cast component PreviewAudioArea
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

test.suite("PreviewAudioArea")

test.case("fits the note above the player, which spans the bottom of the area", function()
    local s = setup()
    s.area:show_medium(media.Type.AUDIO, s.source, s.data)
    local component = preview(s)
    local player = player_of(component)
    local note = child_of_class(component, Image)

    local player_w, player_h = player:get_size()
    test.assert_eq(player_w, AREA_W)
    test.assert_deep_eq({
        player:get_position()
    }, {
        -AREA_W * 0.5,
        AREA_H * 0.5 - player_h
    })

    local x, y, w, h = note:get_position_and_outer_size()
    local free_h = AREA_H - player_h - 2 * Consts.PADDING
    test.assert_near(h, free_h, 1e-9, "the height limits the fit of the square note")
    test.assert_near(w, free_h)
    test.assert_near(x + w * 0.5, 0, 1e-9, "centered across")
    test.assert_near(y + h * 0.5, -player_h * 0.5, 1e-9, "centered above the player")
    finish(s)
end)

test.case("the player plays the source for its duration", function()
    local s = setup()
    s.area:show_medium(media.Type.AUDIO, s.source, s.data)
    local player = player_of(preview(s))
    ---@diagnostic disable-next-line: invisible
    test.assert_eq(player._time:get_text(), "0:00 / 0:02")
    ---@diagnostic disable-next-line: invisible
    player._play_button:on_click()
    test.assert_deep_eq(s.source.log, {
        "play"
    })
    finish(s)
end)

test.case("a reset of the area destroys the preview and stops the sound", function()
    local s = setup()
    s.form:show()
    s.area:show_medium(media.Type.AUDIO, s.source, s.data)
    local component = preview(s)
    ---@diagnostic disable-next-line: invisible
    player_of(component)._play_button:on_click()
    s.area:reset()
    test.assert_false(lifetime.alive(component))
    test.assert_deep_eq(s.source.log, {
        "play",
        "stop"
    })
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(s.form._inputs, {}, "the buttons left the form")
    test.assert_deep_eq(s.area.content_parent:get_children(), {})
    finish(s)
end)

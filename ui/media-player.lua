local Consts = require("app.consts")
local Control = require("controls.control")
local Rectangle = require("controls.rectangle")
local SeekBar = require("ui.seek-bar")
local Text = require("controls.text")
local TextButton = require("ui.text-button")
local Utils = require("utils.utils")

---@class MediaPlayer: Control
---@field private _playback Playback
---@field private _play_button TextButton
---@field private _stop_button TextButton
---@field private _time Text
---@field private _seek_bar SeekBar
---@field private _was_playing boolean What the caption of the play button shows
local MediaPlayer = class("MediaPlayer", Control)

local PLAY_CAPTION = "Play"
local PAUSE_CAPTION = "Pause"
local STOP_CAPTION = "Stop"

---@param seconds number
---@param with_hours boolean
---@return string
local function _format_time(seconds, with_hours)
    local total = math.floor(seconds)
    local hours, minutes, secs = math.floor(total / 3600), math.floor(total % 3600 / 60), total % 60
    if with_hours then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%d:%02d", math.floor(total / 60), secs)
end

---@param position number
---@param duration number|nil
---@return string
local function _format_progress(position, duration)
    if not duration then
        return _format_time(position, position >= 3600)
    end
    local with_hours = duration >= 3600
    return _format_time(Utils.clamp(0, duration, position), with_hours) .. " / " .. _format_time(duration, with_hours)
end

---@param parent Control|nil
---@param form_screen FormScreen The screen the buttons belong to
---@param width number
---@param playback Playback
function MediaPlayer:init(parent, form_screen, width, playback)
    Control.init(self, parent, width, 0)
    self._playback = playback
    local background = Rectangle(self, width, 0, Consts.BACKGROUND_COLOR)

    self._play_button = TextButton(self, form_screen, PAUSE_CAPTION, function()
        self:_toggle()
    end)
    self._play_button:set_scale(Consts.PANEL_FIELD_SCALE)
    self._play_button:set_position(Consts.PADDING, Consts.PADDING)
    local caption_width, row_height = self._play_button:get_outer_size()
    self._play_button:set_text(PLAY_CAPTION)
    caption_width = math.max(caption_width, (self._play_button:get_outer_size()))
    self._was_playing = false

    self._stop_button = TextButton(self, form_screen, STOP_CAPTION, function()
        self:_stop()
    end)
    self._stop_button:set_scale(Consts.PANEL_FIELD_SCALE)
    self._stop_button:set_position(2 * Consts.PADDING + caption_width, Consts.PADDING)

    self._time = Text(self, "", Consts.FOREGROUND_COLOR)
    self._time:set_scale(Consts.PANEL_FIELD_SCALE)

    self._seek_bar = SeekBar(self, width - 2 * Consts.PADDING)
    self._seek_bar:set_position(Consts.PADDING, 2 * Consts.PADDING + row_height)
    self._seek_bar.sought:register(self, self.on_sought)
    local _, bar_height = self._seek_bar:get_size()

    local height = 3 * Consts.PADDING + row_height + bar_height
    self:set_size(width, height)
    background:set_size(width, height)

    self:_refresh()
    app.update_event:register(self, self.on_update)
end

---@private
function MediaPlayer:_update_caption()
    local is_playing = self._playback:is_playing()
    if is_playing ~= self._was_playing then
        self._was_playing = is_playing
        self._play_button:set_text(is_playing and PAUSE_CAPTION or PLAY_CAPTION)
    end
end

---@private
function MediaPlayer:_update_time()
    local playback = self._playback
    local text = _format_progress(playback:tell(), playback:get_duration())
    if text ~= self._time:get_text() then
        self._time:set_text(text)
        local width = self:get_size()
        local text_width = self._time:get_outer_size()
        self._time:set_position(width - Consts.PADDING - text_width, Consts.PADDING)
    end
end

---@private
function MediaPlayer:_update_seek_bar()
    local duration = self._playback:get_duration()
    self._seek_bar:set_seekable(duration ~= nil)
    if duration and not self._seek_bar:is_dragging() then
        self._seek_bar:set_fraction(self._playback:tell() / duration)
    end
end

---@private
function MediaPlayer:_refresh()
    self:_update_caption()
    self:_update_time()
    self:_update_seek_bar()
end

---@private
function MediaPlayer:_toggle()
    local playback = self._playback
    if playback:is_playing() then
        playback:pause()
    else
        local duration = playback:get_duration()
        if duration and playback:tell() >= duration then
            playback:stop()
        end
        playback:play()
    end
    self:_refresh()
end

---@private
function MediaPlayer:_stop()
    self._playback:stop()
    self:_refresh()
end

---@param dt number
function MediaPlayer:on_update(dt)
    self:_refresh()
end

---@param fraction number
function MediaPlayer:on_sought(fraction)
    local duration = self._playback:get_duration()
    if duration then
        self._playback:seek(fraction * duration)
        self:_refresh()
    end
end

---@param reason lifetime.Reason A death the collector found leaves the playback alone: its LÖVE objects may be freed already
function MediaPlayer:release(reason)
    if reason ~= "unreachable" and reason ~= "exit" then
        self._playback:stop()
    end
    Control.release(self, reason)
end

return MediaPlayer

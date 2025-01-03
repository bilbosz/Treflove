local Logo = require("game.logo")
local Rectangle = require("controls.rectangle")
local Screen = require("screens.screen")
local UpdateEventListener = require("events.update-event").Listener

---@class ScreenSaver: Screen, UpdateEventListener
---@field private _background Rectangle
---@field private _dir_rot number
---@field private _dir_x number
---@field private _dir_y number
---@field private _logo Logo
local ScreenSaver = class("ScreenSaver", Screen, UpdateEventListener)

function ScreenSaver:init()
    Screen.init(self)
end

function ScreenSaver:show()
    assert(not config.window.resizable)
    Screen.show(self)
    self.screen:set_size(app.width, app.height)

    self._background = Rectangle(self.screen, app.width, app.height, {
        1,
        1,
        1,
        1
    })

    self._logo = Logo(self.screen)

    self._dir_rot = 1
    self._dir_x, self._dir_y = 1, 1

    app.update_event_manager:register_listener(self)
end

---@param dt number
function ScreenSaver:on_update(dt)
    local logo = self._logo
    logo:set_rotation(logo:get_rotation() + dt * self._dir_rot)

    local x, y = logo:get_position()
    local r = logo:get_size() * 0.5
    local w, h = self.screen:get_size()
    local move = 60 * dt

    local new_x, new_y = x + self._dir_x * move, y + self._dir_y * move

    local collided = false
    if new_x - r < 0 then
        collided = true
        self._dir_x = -self._dir_x
        new_x = -(new_x - r) + r
    end
    if new_x + r >= w then
        collided = true
        self._dir_x = -self._dir_x
        new_x = w - ((new_x + r) - w) - r
    end
    if new_y - r < 0 then
        collided = true
        self._dir_y = -self._dir_y
        new_y = -(new_y - r) + r
    end
    if new_y + r >= h then
        collided = true
        self._dir_y = -self._dir_y
        new_y = h - ((new_y + r) - h) - r
    end
    if collided then
        for k = 1, 3 do
            self._logo.color[k] = math.random()
        end
        self._dir_rot = -self._dir_rot
    end

    logo:set_position(new_x, new_y)
end

return ScreenSaver

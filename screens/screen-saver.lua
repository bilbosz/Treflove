local Screen = require("screens.screen")
local UpdateEventListener = require("events.update-event").Listener
local Rectangle = require("controls.rectangle")
local Logo = require("game.logo")

---@class ScreenSaver: Screen, UpdateEventListener
local ScreenSaver = class("ScreenSaver", Screen, UpdateEventListener)

function ScreenSaver:init()
    Screen.init(self)
end

function ScreenSaver:show()
    assert(not config.window.resizable)
    Screen.show(self)
    self.screen:set_size(app.width, app.height)

    self.background = Rectangle(self.screen, app.width, app.height, {
        1,
        1,
        1,
        1
    })

    self.logo = Logo(self.screen)

    self.dirRot = 1
    self.dirX, self.dirY = 1, 1

    app.update_event_manager:register_listener(self)
end

function ScreenSaver:on_update(dt)
    local logo = self.logo
    logo:set_rotation(logo:get_rotation() + dt * self.dirRot)

    local x, y = logo:get_position()
    local r = logo:get_size() * 0.5
    local w, h = self.screen:get_size()
    local move = 60 * dt

    local newX, newY = x + self.dirX * move, y + self.dirY * move

    local collided = false
    if newX - r < 0 then
        collided = true
        self.dirX = -self.dirX
        newX = -(newX - r) + r
    end
    if newX + r >= w then
        collided = true
        self.dirX = -self.dirX
        newX = w - ((newX + r) - w) - r
    end
    if newY - r < 0 then
        collided = true
        self.dirY = -self.dirY
        newY = -(newY - r) + r
    end
    if newY + r >= h then
        collided = true
        self.dirY = -self.dirY
        newY = h - ((newY + r) - h) - r
    end
    if collided then
        for k = 1, 3 do
            self.logo.color[k] = math.random()
        end
        self.dirRot = -self.dirRot
    end

    logo:set_position(newX, newY)
end

return ScreenSaver

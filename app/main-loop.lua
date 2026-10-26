---@class love
---@field handlers table<love.Event, fun(...: any)> The callback of every event name, defined by LÖVE's boot script
---@alias MainLoopEventIterator fun(): love.Event|nil, any, any, any, any, any, any
---@class MainLoop: Object
---@field FIXED_DT number The frame delta of a headless run
---@field private _headless boolean
---@field private _paused boolean
---@field private _steps integer Updates still to run while paused
---@field private _skip number Seconds added to the delta of the next update that runs
---@field private _frame integer Updates run so far
local MainLoop = class("MainLoop")

MainLoop.FIXED_DT = 1 / 60

---@param headless boolean Fixed frame delta and no sleep
function MainLoop:init(headless)
    assert_type(headless, "boolean")
    self._headless = headless
    self._paused = false
    self._steps = 0
    self._skip = 0
    self._frame = 0
end

function MainLoop:install()
    ---@return fun(): integer|nil
    function love.run()
        if love.load then
            love.load()
        end
        love.timer.step()
        return function()
            return self:_iterate()
        end
    end
end

function MainLoop:pause()
    self._paused = true
end

function MainLoop:resume()
    self._paused = false
    self._steps = 0
end

---@return boolean
function MainLoop:is_paused()
    return self._paused
end

---@param n integer Updates to run before staying paused again
function MainLoop:step(n)
    assert(self._paused, "only a paused main loop steps")
    assert(n >= 1 and n % 1 == 0, "the number of steps is a positive integer")
    self._steps = self._steps + n
end

---@param seconds number
function MainLoop:skip(seconds)
    assert(seconds >= 0, "the clock only goes forward")
    self._skip = self._skip + seconds
end

---@return integer
function MainLoop:get_frame()
    return self._frame
end

---@private
---@return integer|nil exit_code Once the loop ends
function MainLoop:_dispatch_events()
    love.event.pump()
    ---@type MainLoopEventIterator
    local next_event = love.event.poll()
    for name, a, b, c, d, e, f in next_event do
        if name == "quit" then
            if not love.quit or not love.quit() then
                return a or 0
            end
        end
        love.handlers[name](a, b, c, d, e, f)
    end
    return nil
end

---@private
function MainLoop:_update()
    local dt = love.timer.step()
    if self._headless then
        dt = MainLoop.FIXED_DT
    end
    if self._paused then
        if self._steps == 0 then
            return
        end
        self._steps = self._steps - 1
    end
    -- Cleared before the update, so a skip asked for during it is the next update's
    local skip = self._skip
    self._skip = 0
    self._frame = self._frame + 1
    love.update(dt + skip)
end

---@private
function MainLoop:_draw()
    if love.graphics and love.graphics.isActive() then
        love.graphics.origin()
        love.graphics.clear(love.graphics.getBackgroundColor())
        if love.draw then
            love.draw()
        end
        love.graphics.present()
    end
end

---@private
---@return integer|nil exit_code Once the loop ends
function MainLoop:_iterate()
    local exit_code = self:_dispatch_events()
    if exit_code then
        return exit_code
    end
    app.service_event:trigger()
    self:_update()
    self:_draw()
    if not self._headless then
        love.timer.sleep(0.001)
    end
    return nil
end

return MainLoop

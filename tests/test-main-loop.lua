local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local MainLoop = require("app.main-loop")
local Event = require("events.event")

---@class TestLoopWorld
---@field loop MainLoop Installed as `love.run`
---@field iterate fun(): integer|nil What `love.run` returned
---@field log string[] What the loop did, in order
---@field queue any[][] The events `love.event.poll` gives next, each its name and arguments
---@field dt number What `love.timer.step` returns
---@field steps integer Calls of `love.timer.step`
---@field updates number[] The delta of every `love.update`, in order
---@field frames integer[] What `get_frame` said during every `love.update`
---@field sleeps number[] The argument of every `love.timer.sleep`
---@field abort_quit boolean What `love.quit` returns
---@field on_update fun(world: TestLoopWorld)|nil Called by `love.update` after it logged
---@field graphics_active boolean What `love.graphics.isActive` returns, when there is a `love.graphics`

---@alias TestLoveCallbackName "load"|"update"|"draw"|"quit"|"run"

---@type TestLoveCallbackName[]
local CALLBACK_NAMES = {
    "load",
    "update",
    "draw",
    "quit",
    "run"
}

---@class TestLoveState
---@field event love.event
---@field timer love.timer
---@field graphics love.graphics|nil
---@field handlers table<love.Event, fun(...: any)>
---@field callbacks table<TestLoveCallbackName, function|nil>

---@return TestLoveState
local function save_love()
    ---@type table<TestLoveCallbackName, function|nil>
    local callbacks = {}
    for _, name in ipairs(CALLBACK_NAMES) do
        callbacks[name] = love[name]
    end
    return {
        event = love.event,
        timer = love.timer,
        graphics = love.graphics,
        handlers = love.handlers,
        callbacks = callbacks
    }
end

---@param callbacks table<TestLoveCallbackName, function|nil>
local function set_callbacks(callbacks)
    ---@type table<TestLoveCallbackName, function|nil>
    local love_callbacks = love
    for _, name in ipairs(CALLBACK_NAMES) do
        love_callbacks[name] = callbacks[name]
    end
end

---@param state TestLoveState
local function restore_love(state)
    love.event = state.event
    love.timer = state.timer
    love.graphics = state.graphics
    love.handlers = state.handlers
    set_callbacks(state.callbacks)
end

---@param world TestLoopWorld
---@return love.event
local function make_event_module(world)
    ---@class TestEventModule: love.event
    local event_module = {}

    function event_module.pump()
    end

    ---@return MainLoopEventIterator
    function event_module.poll()
        return function()
            local entry = table.remove(world.queue, 1)
            if entry then
                return entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7]
            end
            return nil
        end
    end

    return event_module
end

---@param world TestLoopWorld
---@return love.timer
local function make_timer_module(world)
    ---@class TestTimerModule: love.timer
    local timer_module = {}

    ---@return number
    function timer_module.step()
        world.steps = world.steps + 1
        return world.dt
    end

    ---@param s number
    function timer_module.sleep(s)
        table.insert(world.sleeps, s)
    end

    return timer_module
end

---@param world TestLoopWorld
---@return love.graphics
local function make_graphics_module(world)
    ---@class TestGraphicsModule: love.graphics
    local graphics_module = {}

    ---@return boolean
    function graphics_module.isActive()
        return world.graphics_active
    end

    function graphics_module.origin()
        table.insert(world.log, "origin")
    end

    ---@return number, number, number, number
    function graphics_module.getBackgroundColor()
        return 0.1, 0.2, 0.3, 1
    end

    ---@param r number
    ---@param g number
    ---@param b number
    ---@param a number
    function graphics_module.clear(r, g, b, a)
        table.insert(world.log, string.format("clear %s %s %s %s", r, g, b, a))
    end

    function graphics_module.present()
        table.insert(world.log, "present")
    end

    return graphics_module
end

---@param world TestLoopWorld
local function install_love(world)
    love.event = make_event_module(world)
    love.timer = make_timer_module(world)
    love.graphics = nil
    love.handlers = {
        ---@param key love.KeyConstant
        keypressed = function(key)
            table.insert(world.log, "keypressed " .. key)
        end,
        quit = function()
            table.insert(world.log, "quit handler")
        end
    }
    set_callbacks({
        load = function()
            table.insert(world.log, "load")
        end,
        ---@param dt number
        update = function(dt)
            table.insert(world.log, "update")
            table.insert(world.updates, dt)
            table.insert(world.frames, world.loop:get_frame())
            if world.on_update then
                world.on_update(world)
            end
        end,
        draw = function()
            table.insert(world.log, "draw")
        end,
        ---@return boolean
        quit = function()
            table.insert(world.log, "love.quit")
            return world.abort_quit
        end
    })
end

---@class TestServiceOwner
---@field world TestLoopWorld
local TestServiceOwner = class("TestServiceOwner")

---@param world TestLoopWorld
function TestServiceOwner:init(world)
    self.world = world
end

function TestServiceOwner:on_service()
    table.insert(self.world.log, "service")
end

---@param name string
---@param headless boolean
---@param fn fun(world: TestLoopWorld)
local function loop_case(name, headless, fn)
    test.case(name, function()
        local state = save_love()
        local app_mock = mocks.install_app()
        app_mock.service_event = Event()
        ---@type TestServiceOwner|nil
        local service_owner
        ---@type boolean, any
        local ok, err = pcall(function()
            local loop = MainLoop(headless)
            ---@type TestLoopWorld
            local world = {
                loop = loop,
                iterate = function()
                    return nil
                end,
                log = {},
                queue = {},
                dt = 0.025,
                steps = 0,
                updates = {},
                frames = {},
                sleeps = {},
                abort_quit = false,
                on_update = nil,
                graphics_active = true
            }
            install_love(world)
            service_owner = TestServiceOwner(world)
            app_mock.service_event:register(service_owner, service_owner.on_service)
            loop:install()
            world.iterate = love.run()
            fn(world)
        end)
        restore_love(state)
        if not ok then
            error(err, 0)
        end
    end)
end

---@param world TestLoopWorld
---@param n integer
local function iterate(world, n)
    for _ = 1, n do
        test.assert_eq(world.iterate(), nil, "the loop ended")
    end
end

test.suite("MainLoop")

loop_case("love.run loads and steps the timer once before the first iteration", false, function(world)
    test.assert_deep_eq(world.log, {
        "load"
    })
    test.assert_eq(world.steps, 1)
    test.assert_deep_eq(world.updates, {})
end)

loop_case("a frame in a window updates with the real delta and sleeps", false, function(world)
    iterate(world, 1)
    world.dt = 0.04
    iterate(world, 1)
    test.assert_deep_eq(world.updates, {
        0.025,
        0.04
    })
    test.assert_deep_eq(world.sleeps, {
        0.001,
        0.001
    })
    test.assert_eq(world.steps, 3)
end)

loop_case("a headless frame updates with the fixed delta and never sleeps", true, function(world)
    world.dt = 0.5
    iterate(world, 2)
    test.assert_deep_eq(world.updates, {
        MainLoop.FIXED_DT,
        MainLoop.FIXED_DT
    })
    test.assert_deep_eq(world.sleeps, {})
    test.assert_eq(world.steps, 3, "the timer is stepped all the same")
end)

loop_case("an iteration dispatches every polled event, then triggers the service event, then updates", true, function(world)
    world.queue = {
        {
            "keypressed",
            "a",
            "a",
            false
        },
        {
            "keypressed",
            "b",
            "b",
            false
        }
    }
    iterate(world, 1)
    test.assert_deep_eq(world.log, {
        "load",
        "keypressed a",
        "keypressed b",
        "service",
        "update"
    })
    test.assert_deep_eq(world.queue, {})
end)

loop_case("a skip is added to the next update only, accumulated", true, function(world)
    world.loop:skip(2)
    world.loop:skip(0.5)
    iterate(world, 2)
    test.assert_near(world.updates[1], MainLoop.FIXED_DT + 2.5)
    test.assert_eq(world.updates[2], MainLoop.FIXED_DT)
    test.assert_error(function()
        world.loop:skip(-1)
    end, "a negative skip")
end)

loop_case("a skip asked for during an update is the next update's", false, function(world)
    world.on_update = function()
        if #world.updates == 1 then
            world.loop:skip(10)
        end
    end
    iterate(world, 3)
    test.assert_deep_eq(world.updates, {
        0.025,
        10.025,
        0.025
    })
end)

loop_case("paused, the loop still dispatches, services, draws and sleeps but runs no update", false, function(world)
    love.graphics = make_graphics_module(world)
    world.loop:pause()
    test.assert_true(world.loop:is_paused())
    world.loop:skip(3)
    world.queue = {
        {
            "keypressed",
            "x",
            "x",
            false
        }
    }
    world.log = {}
    iterate(world, 2)
    test.assert_deep_eq(world.log, {
        "keypressed x",
        "service",
        "origin",
        "clear 0.1 0.2 0.3 1",
        "draw",
        "present",
        "service",
        "origin",
        "clear 0.1 0.2 0.3 1",
        "draw",
        "present"
    })
    test.assert_deep_eq(world.updates, {})
    test.assert_eq(#world.sleeps, 2)
    test.assert_eq(world.steps, 3, "the timer is stepped every iteration, so the pause piles up no delta")

    world.loop:resume()
    test.assert_false(world.loop:is_paused())
    iterate(world, 1)
    test.assert_deep_eq(world.updates, {
        3.025
    }, "the pending skip waited for the update")
end)

loop_case("a step runs that many updates, one per iteration, and stays paused", true, function(world)
    test.assert_error(function()
        world.loop:step(1)
    end, "a step while running")
    world.loop:pause()
    test.assert_error(function()
        world.loop:step(0)
    end, "no steps")
    test.assert_error(function()
        world.loop:step(1.5)
    end, "a fraction of a step")
    world.loop:step(2)
    world.loop:step(1)
    iterate(world, 5)
    test.assert_eq(#world.updates, 3)
    test.assert_true(world.loop:is_paused())

    world.loop:step(4)
    iterate(world, 1)
    world.loop:resume()
    world.loop:pause()
    iterate(world, 2)
    test.assert_eq(#world.updates, 4, "a resume drops the steps still pending")
end)

loop_case("the frame count is the number of updates run, the current one included", true, function(world)
    test.assert_eq(world.loop:get_frame(), 0)
    iterate(world, 2)
    world.loop:pause()
    iterate(world, 3)
    world.loop:step(1)
    iterate(world, 2)
    test.assert_eq(world.loop:get_frame(), 3)
    test.assert_deep_eq(world.frames, {
        1,
        2,
        3
    })
end)

loop_case("the quit event ends the loop with its code after love.quit, before anything else of the iteration", false, function(world)
    world.queue = {
        {
            "quit",
            3
        },
        {
            "keypressed",
            "a",
            "a",
            false
        }
    }
    world.log = {}
    test.assert_eq(world.iterate(), 3)
    test.assert_deep_eq(world.log, {
        "love.quit"
    })
    test.assert_deep_eq(world.updates, {})
end)

loop_case("a quit event without a code ends the loop with 0", true, function(world)
    world.queue = {
        {
            "quit"
        }
    }
    test.assert_eq(world.iterate(), 0)
end)

loop_case("a quit that love.quit aborts goes to its handler and the loop goes on", true, function(world)
    world.abort_quit = true
    world.queue = {
        {
            "quit",
            1
        }
    }
    world.log = {}
    iterate(world, 1)
    test.assert_deep_eq(world.log, {
        "love.quit",
        "quit handler",
        "service",
        "update"
    })
end)

loop_case("an inactive graphics module draws nothing", false, function(world)
    love.graphics = make_graphics_module(world)
    world.graphics_active = false
    world.log = {}
    iterate(world, 1)
    test.assert_deep_eq(world.log, {
        "service",
        "update"
    })
end)

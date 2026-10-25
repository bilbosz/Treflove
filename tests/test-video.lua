local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Control = require("controls.control")
local Video = require("controls.video")

---@class TestVideoGraphicsLog
---@field calls string[] Every drawing call, in order
---@field drawn love.Drawable[] What every `draw` drew, in order

---@return TestVideoGraphicsLog
local function install_graphics()
    ---@type TestVideoGraphicsLog
    local log = {
        calls = {},
        drawn = {}
    }

    ---@param name string
    ---@return fun(...)
    local function record(name)
        return function(...)
            local args = {}
            for i = 1, select("#", ...) do
                local arg = select(i, ...)
                if type(arg) == "number" then
                    table.insert(args, tostring(arg))
                end
            end
            table.insert(log.calls, name .. "(" .. table.concat(args, ", ") .. ")")
        end
    end

    local record_draw = record("draw")

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        getDimensions = function()
            return 800, 600
        end,
        setColor = function()
        end,
        push = function()
        end,
        pop = function()
        end,
        replaceTransform = record("replaceTransform"),
        origin = record("origin"),
        translate = record("translate"),
        scale = record("scale"),
        ---@param drawable love.Drawable
        draw = function(drawable)
            table.insert(log.drawn, drawable)
            record_draw()
        end
    }
    return log
end

---@return TestVideoFake
local function make_video()
    ---@class TestVideoFake: love.Video
    local video = {}

    ---@return number, number
    function video:getDimensions()
        return 100, 50
    end

    return video
end

---@return TestVideoGraphicsLog
---@return Control root
local function setup()
    mocks.install_app()
    mocks.ensure_love_math()
    return install_graphics(), Control()
end

---@param log TestVideoGraphicsLog
---@return string[]
local function take_calls(log)
    local calls = log.calls
    log.calls = {}
    return calls
end

test.suite("Video")

test.case("is sized in texels and draws its video", function()
    local log, root = setup()
    local love_video = make_video()
    local video = Video(root, love_video)
    test.assert_deep_eq({
        video:get_size()
    }, {
        100,
        50
    })
    video:draw()
    test.assert_deep_eq(log.drawn, {
        love_video
    })
end)

test.case("an axis-aligned video is drawn at a whole-pixel position", function()
    local log, root = setup()
    root:set_scale(0.5)
    local video = Video(root, make_video())
    video:set_position(20.8, 41.2)

    video:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "origin()",
        "translate(10, 21)",
        "scale(0.5)",
        "draw()"
    })
end)

test.case("one texel per screen pixel when the scale is within half a pixel of it", function()
    local log, root = setup()
    local video = Video(root, make_video())

    video:set_scale(1.004)
    video:draw()
    test.assert_eq(take_calls(log)[4], "scale(1)", "the far edge moves by 0.4 px")

    video:set_scale(1.006)
    video:draw()
    local scale = assert(tonumber(string.match(take_calls(log)[4], "^scale%((.*)%)$")))
    test.assert_near(scale, 1.006, 1e-5, "the far edge moves by 0.6 px")
end)

test.case("a rotated video keeps its transform", function()
    local log, root = setup()
    root:set_scale(0.5)
    local video = Video(root, make_video())
    video:set_rotation(math.pi * 0.25)

    video:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "draw()"
    })
end)

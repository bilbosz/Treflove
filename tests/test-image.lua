local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local images = require("graphics.images")
local Control = require("controls.control")
local Image = require("controls.image")

---@class TestImageGraphicsLog
---@field calls string[] Every drawing call, in order
---@field made number How many images were made

---@return TestImageGraphicsLog
local function install_graphics()
    local log = {
        calls = {},
        made = 0
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

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        newImage = function()
            log.made = log.made + 1
            return {
                getDimensions = function()
                    return 100, 50
                end,
                setFilter = function()
                end,
                setMipmapFilter = function()
                end
            }
        end,
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
        draw = record("draw")
    }
    return log
end

---@return TestImageGraphicsLog
---@return Control root
local function setup()
    mocks.install_app()
    mocks.ensure_love_math()
    mocks.install_love_filesystem({})
    local log = install_graphics()
    images.clear()
    return log, Control()
end

---@param log TestImageGraphicsLog
---@return string[]
local function take_calls(log)
    local calls = log.calls
    log.calls = {}
    return calls
end

test.suite("Image")

test.case("is sized in texels and shares its file's image with the others of the path", function()
    local log = setup()
    local image = Image(nil, "a.png")
    test.assert_deep_eq({
        image:get_size()
    }, {
        100,
        50
    })
    Image(nil, "a.png")
    test.assert_eq(log.made, 1, "one image per path")
    Image(nil, "b.png")
    test.assert_eq(log.made, 2)
    mocks.restore_love_filesystem()
end)

test.case("wraps an image it is given", function()
    local log = setup()
    local image = Image(nil, love.graphics.newImage("a.png"))
    local made = log.made
    test.assert_deep_eq({
        image:get_size()
    }, {
        100,
        50
    })
    test.assert_eq(log.made, made, "nothing made for it")
    mocks.restore_love_filesystem()
end)

test.case("an axis-aligned image is drawn at a whole-pixel position", function()
    local log, root = setup()
    root:set_scale(0.5)
    local image = Image(root, "a.png")
    image:set_position(20.8, 41.2)

    image:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "origin()",
        "translate(10, 21)",
        "scale(0.5)",
        "draw()"
    })
    mocks.restore_love_filesystem()
end)

test.case("one texel per screen pixel when the scale is within half a pixel of it", function()
    local log, root = setup()
    local image = Image(root, "a.png")

    image:set_scale(1.004)
    image:draw()
    test.assert_eq(take_calls(log)[4], "scale(1)", "the far edge moves by 0.4 px")

    image:set_scale(1.006)
    image:draw()
    local scale = assert(tonumber(string.match(take_calls(log)[4], "^scale%((.*)%)$")))
    test.assert_near(scale, 1.006, 1e-5, "the far edge moves by 0.6 px")
    mocks.restore_love_filesystem()
end)

test.case("a rotated image keeps its transform", function()
    local log, root = setup()
    root:set_scale(0.5)
    local image = Image(root, "a.png")
    image:set_rotation(math.pi * 0.25)

    image:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "draw()"
    })
    mocks.restore_love_filesystem()
end)

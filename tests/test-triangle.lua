local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Triangle = require("controls.triangle")

test.suite("Triangle")

test.case("a triangle fills its box pointing down, in its color", function()
    mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local graphics = assert(love.graphics)
    local polygon, set_color = graphics.polygon, graphics.setColor
    ---@type string[]
    local draws = {}

    ---@param mode love.DrawMode
    ---@param ... number
    function graphics.polygon(mode, ...)
        table.insert(draws, mode .. " " .. table.concat({
            ...
        }, ","))
    end

    ---@param red number|number[]
    function graphics.setColor(red)
        if type(red) == "table" then
            table.insert(draws, "color " .. table.concat(red, ","))
        end
    end

    local triangle = Triangle(nil, 16, 10, {
        0.25,
        0.5,
        0.75
    })
    triangle:draw()
    triangle:set_color({
        1,
        0,
        0
    })
    triangle:draw()
    graphics.polygon, graphics.setColor = polygon, set_color

    test.assert_deep_eq(draws, {
        "color 0.25,0.5,0.75",
        "fill 0,0,16,0,8,10",
        "color 1,0,0",
        "fill 0,0,16,0,8,10"
    })
    test.assert_deep_eq(triangle:get_color(), {
        1,
        0,
        0
    })
    lifetime.destroy(triangle)
end)

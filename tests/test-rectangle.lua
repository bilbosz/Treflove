local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Rectangle = require("controls.rectangle")

local function _no_op()
end

---@param line_width number
---@return string[] draws "mode x,y,w,h" per `rectangle`
local function install_graphics(line_width)
    ---@type string[]
    local draws = {}

    ---@param mode love.DrawMode
    ---@param x number
    ---@param y number
    ---@param w number
    ---@param h number
    local function rectangle(mode, x, y, w, h)
        table.insert(draws, string.format("%s %s,%s,%s,%s", mode, x, y, w, h))
    end

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        getDimensions = function()
            return 800, 600
        end,
        getLineWidth = function()
            return line_width
        end,
        setColor = _no_op,
        push = _no_op,
        pop = _no_op,
        replaceTransform = _no_op,
        rectangle = rectangle
    }
    return draws
end

test.suite("Rectangle")

test.case("a border draws its line inside the box, a filled one fills it", function()
    mocks.install_app()
    mocks.ensure_love_math()
    local draws = install_graphics(2)
    local border = Rectangle(nil, 100, 50, nil, true)
    local filled = Rectangle(nil, 100, 50)

    border:draw()
    filled:draw()

    test.assert_deep_eq(draws, {
        "line 1,1,98,48",
        "fill 0,0,100,50"
    })
    lifetime.destroy(border)
    lifetime.destroy(filled)
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Control = require("controls.control")
local ClippingMask = require("controls.clipping-mask")
local ClippingRectangle = require("controls.clipping-rectangle")
local Rectangle = require("controls.rectangle")

local function _no_op()
end

---@return string[] draws "x,y,w,h of the scissor" or "none" per `rectangle`
local function install_graphics()
    ---@type string[]
    local draws = {}
    ---@type number[]|nil
    local scissor = nil

    ---@return number|nil, number|nil, number|nil, number|nil
    local function get_scissor()
        if not scissor then
            return nil, nil, nil, nil
        end
        return scissor[1], scissor[2], scissor[3], scissor[4]
    end

    ---@param x number|nil
    ---@param y number|nil
    ---@param w number|nil
    ---@param h number|nil
    local function set_scissor(x, y, w, h)
        if x == nil then
            scissor = nil
        else
            scissor = {
                x,
                y,
                w,
                h
            }
        end
    end

    ---@param x number
    ---@param y number
    ---@param w number
    ---@param h number
    local function intersect_scissor(x, y, w, h)
        if not scissor then
            scissor = {
                x,
                y,
                w,
                h
            }
            return
        end
        local min_x, min_y = math.max(scissor[1], x), math.max(scissor[2], y)
        local max_x, max_y = math.min(scissor[1] + scissor[3], x + w), math.min(scissor[2] + scissor[4], y + h)
        scissor = {
            min_x,
            min_y,
            math.max(0, max_x - min_x),
            math.max(0, max_y - min_y)
        }
    end

    local function rectangle()
        if scissor then
            table.insert(draws, table.concat({
                scissor[1],
                scissor[2],
                scissor[3],
                scissor[4]
            }, ","))
        else
            table.insert(draws, "none")
        end
    end

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        getDimensions = function()
            return 800, 600
        end,
        setColor = _no_op,
        push = _no_op,
        pop = _no_op,
        replaceTransform = _no_op,
        getScissor = get_scissor,
        setScissor = set_scissor,
        intersectScissor = intersect_scissor,
        rectangle = rectangle
    }
    return draws
end

test.suite("ClippingRectangle")

test.case("a nested clip is the intersection, and the enclosing clip is back for what follows it", function()
    mocks.install_app()
    mocks.ensure_love_math()
    local draws = install_graphics()
    local root = Control()
    local outer = ClippingRectangle(root, 100, 100)
    outer:set_position(10, 10)
    local inner = ClippingRectangle(outer, 100, 100)
    inner:set_position(50, 50)
    Rectangle(inner, 500, 500)
    Rectangle(outer, 500, 500)
    Rectangle(root, 500, 500)

    root:draw()

    test.assert_deep_eq(draws, {
        "60,60,50,50",
        "10,10,100,100",
        "none"
    })
    lifetime.destroy(root)
end)

---@param clip Control A 100 x 100 clip at (10, 10) under a root at the origin
---@param root Control
---@param app_mock AppMock
local function assert_bounds_are_the_box(clip, root, app_mock)
    local child = Rectangle(clip, 100, 100)
    child:set_position(90, 90)
    test.assert_deep_eq({
        clip:get_global_recursive_aabb():get_bounds()
    }, {
        10,
        10,
        110,
        110
    }, "the clip's bounds are its box")
    test.assert_deep_eq({
        child:get_global_recursive_aabb():get_bounds()
    }, {
        100,
        100,
        200,
        200
    }, "the child's are its own")
    test.assert_deep_eq({
        root:get_global_recursive_aabb():get_bounds()
    }, {
        0,
        0,
        110,
        110
    }, "the parent's end at the clip")

    ---@type string[]
    local log = {}
    ---@param _ Control
    ---@param x number
    ---@param y number
    local function on_child_down(_, x, y)
        table.insert(log, string.format("%d,%d", x, y))
    end
    local manager = app_mock.pointer_event_manager
    manager.pointer_down:register(child, on_child_down)
    manager:dispatch_pointer_down(150, 150, 1)
    manager:dispatch_pointer_down(105, 105, 1)
    test.assert_deep_eq(log, {
        "105,105"
    }, "the clipped part of the child is not hit")
end

test.case("a clipping rectangle's bounds are its box: what it clips is not hit", function()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local root = Control()
    app_mock.root = root
    local clip = ClippingRectangle(root, 100, 100)
    clip:set_position(10, 10)
    assert_bounds_are_the_box(clip, root, app_mock)
    lifetime.destroy(root)
end)

test.case("a clipping mask's bounds are its box too", function()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    local root = Control()
    app_mock.root = root
    local clip = ClippingMask(root, 100, 100, function()
    end)
    clip:set_position(10, 10)
    assert_bounds_are_the_box(clip, root, app_mock)
    lifetime.destroy(root)
end)

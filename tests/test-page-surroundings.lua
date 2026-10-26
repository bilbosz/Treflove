local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local images = require("graphics.images")
local Consts = require("app.consts")
local Control = require("controls.control")
local Image = require("controls.image")
local PageSurroundings = require("game.page.page-surroundings")

---@class TestSurroundingsGraphicsLog
---@field calls string[] The shader switches and the draws, in order
---@field quad_made number[] The arguments of `newQuad`
---@field viewport number[] The last viewport set
---@field uniforms table<string, number[]> The last values sent per uniform
---@field sent_unset boolean Whether a uniform was sent while the shader was not set
---@field drawn {[1]: love.Texture, [2]: love.Quad, [3]: number[]}|nil The last draw: the image, the quad and the numbers
---@field image love.Image The image every `newImage` returns
---@field quad love.Quad|nil The quad made
---@field shader love.Shader|nil The shader made
---@field shader_source string|nil The source it was made from
---@field current_shader love.Shader|nil The shader set

---@return TestSurroundingsImage
local function make_image()
    ---@class TestSurroundingsImage: love.Image
    local image = {}

    ---@return number, number
    function image:getDimensions()
        return 100, 50
    end

    function image:setFilter()
    end

    function image:setMipmapFilter()
    end

    return image
end

---@param log TestSurroundingsGraphicsLog
---@return TestSurroundingsQuad
local function make_quad(log)
    ---@class TestSurroundingsQuad: love.Quad
    local quad = {}

    ---@param x number
    ---@param y number
    ---@param w number
    ---@param h number
    function quad:setViewport(x, y, w, h)
        log.viewport = {
            x,
            y,
            w,
            h
        }
    end

    return quad
end

---@param log TestSurroundingsGraphicsLog
---@return TestSurroundingsShader
local function make_shader(log)
    ---@class TestSurroundingsShader: love.Shader
    local shader = {}

    ---@param name string
    ---@param value number|number[]
    function shader:send(name, value)
        log.sent_unset = log.sent_unset or log.current_shader ~= self
        log.uniforms[name] = type(value) == "table" and value or {
            value
        }
    end

    return shader
end

---@param glsl3 boolean What `getSupported` reports
---@return TestSurroundingsGraphicsLog
local function install_graphics(glsl3)
    ---@type TestSurroundingsGraphicsLog
    local log = {
        calls = {},
        quad_made = {},
        viewport = {},
        uniforms = {},
        sent_unset = false,
        image = make_image()
    }

    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        newImage = function()
            return log.image
        end,
        newQuad = function(...)
            log.quad_made = {
                ...
            }
            local quad = make_quad(log)
            log.quad = quad
            return quad
        end,
        getSupported = function()
            return {
                glsl3 = glsl3
            }
        end,
        newShader = function(source)
            log.shader_source = source
            local shader = make_shader(log)
            log.shader = shader
            return shader
        end,
        setShader = function(shader)
            log.current_shader = shader
            table.insert(log.calls, shader and shader == log.shader and "setShader(shader)" or "setShader()")
        end,
        draw = function(texture, quad, ...)
            log.drawn = {
                texture,
                quad,
                {
                    ...
                }
            }
            table.insert(log.calls, "draw")
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
        replaceTransform = function()
        end
    }
    return log
end

---@class TestSurroundingsSetup
---@field log TestSurroundingsGraphicsLog
---@field page Control
---@field map Image
---@field surroundings PageSurroundings

---A 400 x 300 page drawn at half a pixel per unit; the 100 x 50 texel map, 10 m wide, centered at (200, 150), half a unit per texel
---@param glsl3 boolean|nil Whether `getSupported` reports GLSL 3; it does by default
---@return TestSurroundingsSetup
local function setup(glsl3)
    mocks.install_app()
    mocks.ensure_love_math()
    mocks.install_love_filesystem({})
    local log = install_graphics(glsl3 ~= false)
    images.clear()
    local root = Control()
    root:set_scale(0.5)
    local page = Control(root, 400, 300)
    local map = Image(nil, "map.png")
    local surroundings = PageSurroundings(page, map, 10)
    page:add_child(map)
    map:set_origin(50, 25)
    map:set_position(200, 150)
    map:set_scale(0.5)
    return {
        log = log,
        page = page,
        map = map,
        surroundings = surroundings
    }
end

---@param actual number[]
---@param expected number[]
---@param message string
local function assert_numbers(actual, expected, message)
    test.assert_eq(#actual, #expected, message .. ": the count")
    for i, v in ipairs(expected) do
        test.assert_near(actual[i], v, 1e-6, message .. " " .. i)
    end
end

test.suite("PageSurroundings")

test.case("takes its page's size and draws the map through a quad over the whole view, in the map's texels", function()
    local s = setup()
    test.assert_deep_eq({
        s.surroundings:get_size()
    }, {
        400,
        300
    })
    assert_numbers(s.log.quad_made, {
        0,
        0,
        1,
        1,
        100,
        50
    }, "the quad's reference size is the map's")

    s.surroundings:draw()
    assert_numbers(s.log.viewport, {
        -350,
        -275,
        800,
        600
    }, "the view's rectangle in the map's texels")
    local drawn = assert(s.log.drawn)
    test.assert_eq(drawn[1], s.log.image)
    test.assert_eq(drawn[2], s.log.quad)
    assert_numbers(drawn[3], {
        0,
        0,
        0,
        0.5,
        0.5
    }, "at the origin, scaled from texels to the view")
    mocks.restore_love_filesystem()
end)

test.case("sends the uniforms of the map's placement", function()
    local s = setup()
    s.surroundings:draw()
    local uniforms = s.log.uniforms
    assert_numbers(uniforms.size, {
        100,
        50
    }, "the map's size in texels")
    assert_numbers(uniforms.growth, {
        Consts.PAGE_SURROUNDINGS_BLUR_GROWTH
    }, "unit-free")
    assert_numbers(uniforms.brightness, {
        Consts.PAGE_SURROUNDINGS_BLUR_BRIGHTNESS
    }, "the shade the far surroundings reach")
    assert_numbers(uniforms.sigma_limit, {
        Consts.PAGE_SURROUNDINGS_BLUR_LIMIT * 10
    }, "ten texels per meter: a 100-texel map 10 m wide")
    assert_numbers(uniforms.base_lod, {
        2
    }, "four texels per screen pixel")
    mocks.restore_love_filesystem()
end)

test.case("sets its shader, which samples at an explicit level, for its draw alone", function()
    local s = setup()
    test.assert_true(string.find(assert(s.log.shader_source), "textureLod", 1, true) ~= nil)
    s.surroundings:draw()
    test.assert_deep_eq(s.log.calls, {
        "setShader(shader)",
        "draw",
        "setShader()"
    })
    test.assert_false(s.log.sent_unset, "the uniforms sent to the set shader")
    mocks.restore_love_filesystem()
end)

test.case("without GLSL 3 makes no shader and draws nothing", function()
    local s = setup(false)
    test.assert_eq(s.log.shader, nil, "no shader made")
    s.surroundings:draw()
    test.assert_deep_eq(s.log.calls, {})
    test.assert_eq(s.log.drawn, nil)
    test.assert_deep_eq(s.log.viewport, {})
    mocks.restore_love_filesystem()
end)

test.case("dies with its page", function()
    local s = setup()
    lifetime.destroy(s.page)
    test.assert_false(lifetime.alive(s.surroundings))
    test.assert_false(lifetime.alive(s.map))
    mocks.restore_love_filesystem()
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local fonts = require("app.fonts")
local Control = require("controls.control")
local Text = require("controls.text")

---@class TestGraphicsLog
---@field calls string[] Every drawing call, in order
---@field fonts table<string, number> The size every font was made at, by its handle
---@field drawable_font string|nil The handle of the font the last text object was given

---@return TestGraphicsLog
local function install_graphics()
    local log = {
        calls = {},
        fonts = {},
        drawable_font = nil
    }
    local font_count = 0

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
        newFont = function(path, size)
            font_count = font_count + 1
            local handle = string.format("%s@%d", string.match(path, "[^/]+$"), size)
            log.fonts[handle] = size
            return {
                handle = handle,
                getHeight = function()
                    return size
                end
            }
        end,
        newText = function(font, text)
            log.drawable_font = font.handle
            return {
                getDimensions = function()
                    return 10 * #text, 20
                end,
                setFont = function(_, new_font)
                    log.drawable_font = new_font.handle
                    table.insert(log.calls, "setFont(" .. new_font.handle .. ")")
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

---@return TestGraphicsLog
---@return Control root
local function setup()
    mocks.install_app()
    mocks.ensure_love_math()
    local log = install_graphics()
    fonts.clear()
    return log, Control()
end

---@param log TestGraphicsLog
---@return string[]
local function take_calls(log)
    local calls = log.calls
    log.calls = {}
    return calls
end

test.suite("Text")

test.case("lays out with the reference font, in model units", function()
    local log = setup()
    local text = Text(nil, "abc")
    test.assert_eq(log.drawable_font, "OpenSans.ttf@80")
    test.assert_deep_eq({
        text:get_size()
    }, {
        30,
        20
    })
    test.assert_eq(text:get_font_height(), 80)
    local input = Text(nil, "", nil, fonts.Kind.USER_INPUT)
    test.assert_eq(log.drawable_font, "NotoSansMono.ttf@80")
    test.assert_eq(input:get_font_height(), 80)
end)

test.case("draws with a font of the on-screen pixel size, snapped to whole pixels", function()
    local log, root = setup()
    root:set_scale(0.4)
    local text = Text(root, "ab")
    text:set_scale(0.325)
    text:set_position(10, 20.6)

    text:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "setFont(OpenSans.ttf@10)",
        "origin()",
        "translate(4, 8)",
        "scale(1)",
        "draw()"
    })
    test.assert_deep_eq({
        text:get_size()
    }, {
        20,
        20
    }, "the layout size is untouched")

    text:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "origin()",
        "translate(4, 8)",
        "scale(1)",
        "draw()"
    }, "the font is kept while the pixel size holds")

    root:set_scale(0.5)
    text:draw()
    test.assert_eq(take_calls(log)[2], "setFont(OpenSans.ttf@13)")

    text:set_text("abc")
    test.assert_eq(log.drawable_font, "OpenSans.ttf@80", "a new text starts from the reference font")
    text:draw()
    test.assert_eq(take_calls(log)[2], "setFont(OpenSans.ttf@13)")
end)

test.case("scales the glyphs when the font size is clamped", function()
    local log, root = setup()
    root:set_scale(10)
    local text = Text(root, "a")

    text:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "setFont(OpenSans.ttf@256)",
        "origin()",
        "translate(0, 0)",
        "scale(3.125)",
        "draw()"
    })
end)

test.case("a rotated text keeps its transform and rescales the glyphs in it", function()
    local log, root = setup()
    root:set_scale(0.5)
    local text = Text(root, "a")
    text:set_rotation(math.pi * 0.25)

    text:draw()
    test.assert_deep_eq(take_calls(log), {
        "replaceTransform()",
        "setFont(OpenSans.ttf@40)",
        "scale(2)",
        "draw()"
    })
end)

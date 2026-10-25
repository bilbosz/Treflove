local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local fonts = require("graphics.fonts")

test.suite("fonts")

test.case("the pixel size is the reference size scaled, rounded and clamped", function()
    test.assert_eq(fonts.pixel_size(1), 80)
    test.assert_eq(fonts.pixel_size(0.13), 10, "10.4 rounds down")
    test.assert_eq(fonts.pixel_size(0.1325), 11, "10.6 rounds up")
    test.assert_eq(fonts.pixel_size(0.01), fonts.MIN_PIXEL_SIZE)
    test.assert_eq(fonts.pixel_size(100), fonts.MAX_PIXEL_SIZE)
end)

test.case("one font per kind and pixel size, made on first use", function()
    mocks.ensure_love_graphics()
    fonts.clear()
    local a = fonts.get(fonts.Kind.DISPLAY, 10)
    test.assert_eq(fonts.get(fonts.Kind.DISPLAY, 10), a, "cached")
    test.assert_eq(a:getHeight(), 10)
    test.assert_true(fonts.get(fonts.Kind.DISPLAY, 11) ~= a, "another size")
    test.assert_true(fonts.get(fonts.Kind.USER_INPUT, 10) ~= a, "another kind")
    test.assert_eq(fonts.reference(fonts.Kind.DISPLAY), fonts.get(fonts.Kind.DISPLAY, fonts.REFERENCE_SIZE))
    fonts.clear()
    test.assert_true(fonts.get(fonts.Kind.DISPLAY, 10) ~= a, "cleared")
end)

---@param name string
---@return TestFaceFile
local function make_font_file(name)
    ---@class TestFaceFile: love.FileData
    ---@field name string
    local file = {
        name = name
    }
    return file
end

test.case("a font file's bytes are a face: one font per face and size, forgotten face by face", function()
    mocks.ensure_love_graphics()
    fonts.clear()
    local fancy = make_font_file("Fancy.ttf")
    local plain = make_font_file("Plain.ttf")
    local fancy_10 = fonts.get(fancy, 10)
    local fancy_reference = fonts.reference(fancy)
    local plain_10 = fonts.get(plain, 10)
    local display_10 = fonts.get(fonts.Kind.DISPLAY, 10)
    test.assert_eq(fonts.get(fancy, 10), fancy_10, "cached")
    test.assert_eq(fancy_10:getHeight(), 10)
    test.assert_true(plain_10 ~= fancy_10, "another face")
    test.assert_true(display_10 ~= fancy_10, "a file's face is not the program's")

    fonts.forget(fancy)
    test.assert_true(fonts.get(fancy, 10) ~= fancy_10, "made again")
    test.assert_true(fonts.reference(fancy) ~= fancy_reference, "every size forgotten")
    test.assert_eq(fonts.get(plain, 10), plain_10, "another face kept")
    test.assert_eq(fonts.get(fonts.Kind.DISPLAY, 10), display_10)
    fonts.clear()
end)

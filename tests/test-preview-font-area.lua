local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local Consts = require("app.consts")
local Control = require("controls.control")
local fonts = require("graphics.fonts")
local FormScreen = require("ui.form-screen")
local PreviewArea = require("game.assets.preview-area.preview-area")
local PreviewFontArea = require("game.assets.preview-area.preview-font-area")
local TextEventManager = require("ui.text-event")
local media = require("utils.media")

local AREA_WIDTH, AREA_HEIGHT = 400, 600
local CHAR_WIDTH_PER_SIZE = 0.25
local HEIGHT_PER_SIZE = 1.25

---@class TestPreviewFontLog
---@field texts string[] Every text object made, as `handle: text`
---@field fonts_made number

---@param face string|TestPreviewFontFile
---@return string
local function face_name(face)
    if type(face) == "string" then
        return string.match(face, "[^/]+$")
    end
    return face.name
end

---@param text string
---@param limit number
---@param char_width number
---@return number width
---@return string[] lines
local function wrap(text, limit, char_width)
    ---@type string[]
    local lines = {}
    ---@type string|nil
    local line
    for word in string.gmatch(text, "%S+") do
        ---@type string
        local candidate = line and line .. " " .. word or word
        if line and #candidate * char_width > limit then
            table.insert(lines, line)
            line = word
        else
            line = candidate
        end
    end
    if line then
        table.insert(lines, line)
    end
    local width = 0
    for _, v in ipairs(lines) do
        width = math.max(width, #v * char_width)
    end
    return width, lines
end

---@param log TestPreviewFontLog
---@param face string|TestPreviewFontFile
---@param size number
---@return TestPreviewFont
local function make_font(log, face, size)
    log.fonts_made = log.fonts_made + 1
    ---@class TestPreviewFont: love.Font
    ---@field handle string
    ---@field char_width number
    local font = {
        handle = string.format("%s@%d", face_name(face), size),
        char_width = size * CHAR_WIDTH_PER_SIZE
    }

    ---@return number
    function font:getHeight()
        return size * HEIGHT_PER_SIZE
    end

    ---@param text string
    ---@return number
    function font:getWidth(text)
        return self.char_width * #text
    end

    ---@param text string
    ---@param limit number
    ---@return number, string[]
    function font:getWrap(text, limit)
        return wrap(text, limit, self.char_width)
    end

    return font
end

---@return TestPreviewFontLog
local function install_graphics()
    mocks.ensure_love_graphics()
    ---@type TestPreviewFontLog
    local log = {
        texts = {},
        fonts_made = 0
    }
    local graphics = love.graphics
    ---@param face string|TestPreviewFontFile
    ---@param size number
    ---@return TestPreviewFont
    graphics.newFont = function(face, size)
        return make_font(log, face, size)
    end
    ---@param font TestPreviewFont
    ---@param text string
    ---@return TestPreviewText
    graphics.newText = function(font, text)
        table.insert(log.texts, font.handle .. ": " .. text)
        ---@class TestPreviewText: love.Text
        local drawable = {}

        ---@return number, number
        function drawable:getDimensions()
            return font.char_width * #text, font:getHeight()
        end

        function drawable:setFont()
        end

        return drawable
    end
    return log
end

---@param name string
---@return TestPreviewFontFile
local function make_font_file(name)
    ---@class TestPreviewFontFile: love.FileData
    ---@field name string
    local file = {
        name = name
    }
    return file
end

---@class TestPreviewFontSetup
---@field app AppMock
---@field keyboard FakeKeyboard
---@field log TestPreviewFontLog
---@field form FormScreen
---@field area PreviewArea
---@field file TestPreviewFontFile

---@return TestPreviewFontSetup
local function setup()
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    local log = install_graphics()
    fonts.clear()
    app_mock.root = Control()
    local keyboard = mocks.make_keyboard()
    app_mock.text_event_manager = TextEventManager(keyboard)
    local form = FormScreen()
    local area = PreviewArea(form:get_control(), AREA_WIDTH, AREA_HEIGHT, {
        set_file = function()
        end
    }, form)
    return {
        app = app_mock,
        keyboard = keyboard,
        log = log,
        form = form,
        area = area,
        file = make_font_file("Fancy.ttf")
    }
end

---@param s TestPreviewFontSetup
---@return PreviewFontArea
local function make_preview(s)
    return PreviewFontArea(s.area, fonts.reference(s.file), s.file)
end

---@param s TestPreviewFontSetup
local function finish(s)
    if lifetime.alive(s.form) then
        lifetime.destroy(s.form)
    end
    fonts.clear()
end

---@param preview PreviewFontArea
---@return Control sample
---@return Rectangle strip
---@return TextInput input
local function parts(preview)
    ---@diagnostic disable-next-line: invisible
    local sample, strip, input = preview._sample, preview._strip, preview._input
    test.assert_deep_eq(preview:get_children(), {
        sample,
        strip
    }, "the sample under the strip")
    test.assert_deep_eq(strip:get_children(), {
        input
    })
    return sample, strip, input
end

---@param sample Control
---@return {[1]: string, [2]: number, [3]: number}[] Every line's text and position
local function lines_of(sample)
    local lines = {}
    for _, line in ipairs(sample:get_children()) do
        ---@cast line Text
        local x, y = line:get_position()
        table.insert(lines, {
            line:get_text(),
            x,
            y
        })
    end
    return lines
end

---@param log TestPreviewFontLog
---@param entry string
---@return boolean
local function made_text(log, entry)
    return table.find_array_idx(log.texts, entry) ~= nil
end

test.suite("PreviewFontArea")

test.case("the field on a strip at the bottom holds the default text, in the file's face", function()
    local s = setup()
    local preview = make_preview(s)
    local _, strip, input = parts(preview)

    test.assert_eq(strip:get_color(), Consts.BACKGROUND_COLOR)
    test.assert_deep_eq({
        strip:get_position()
    }, {
        -AREA_WIDTH * 0.5,
        AREA_HEIGHT * 0.5 - Consts.PANEL_TEXT_INPUT_HEIGHT - 2 * Consts.PADDING
    })
    test.assert_deep_eq({
        strip:get_size()
    }, {
        AREA_WIDTH,
        Consts.PANEL_TEXT_INPUT_HEIGHT + 2 * Consts.PADDING
    })
    test.assert_deep_eq({
        input:get_position()
    }, {
        Consts.PADDING,
        Consts.PADDING
    })
    test.assert_deep_eq({
        input:get_size()
    }, {
        AREA_WIDTH - 2 * Consts.PADDING,
        Consts.PANEL_TEXT_INPUT_HEIGHT
    })
    test.assert_eq(input:get_text(), Consts.FONT_PREVIEW_TEXT)
    test.assert_eq(input:get_form_screen(), s.form)
    test.assert_true(made_text(s.log, "Fancy.ttf@80: " .. Consts.FONT_PREVIEW_TEXT), "the field's text is in the face")
    finish(s)
end)

test.case("the sample wraps the text to the area in the face, line by line, centered from the top", function()
    local s = setup()
    local sample = parts(make_preview(s))
    local scale = Consts.FONT_PREVIEW_SAMPLE_SCALE
    local char_width = fonts.REFERENCE_SIZE * CHAR_WIDTH_PER_SIZE * scale
    local line_height = fonts.REFERENCE_SIZE * HEIGHT_PER_SIZE * scale
    local top = -AREA_HEIGHT * 0.5 + Consts.PADDING

    local first, second = "The quick brown fox jumps over", "the lazy dog"
    test.assert_deep_eq(lines_of(sample), {
        {
            first,
            -#first * char_width * 0.5,
            top
        },
        {
            second,
            -#second * char_width * 0.5,
            top + line_height
        }
    })
    test.assert_true(made_text(s.log, "Fancy.ttf@80: " .. first))
    for _, line in ipairs(sample:get_children()) do
        test.assert_eq(line:get_scale(), scale)
    end
    finish(s)
end)

test.case("an edit rebuilds the sample, the old lines destroyed, as many as fit above the strip", function()
    local s = setup()
    s.form:show()
    local sample, _, input = parts(make_preview(s))
    s.form:focus(input)
    local old_lines = sample:get_children()

    s.app.text_event_manager:key_pressed("end")
    s.app.text_event_manager:text_input("!")
    test.assert_eq(input:get_text(), Consts.FONT_PREVIEW_TEXT .. "!")
    local lines = lines_of(sample)
    test.assert_eq(#lines, 2)
    test.assert_eq(lines[2][1], "the lazy dog!")
    for _, line in ipairs(old_lines) do
        test.assert_false(lifetime.alive(line), "an old line was destroyed")
    end

    s.app.text_event_manager:text_input(string.rep(" more words", 30))
    local line_height = fonts.REFERENCE_SIZE * HEIGHT_PER_SIZE * Consts.FONT_PREVIEW_SAMPLE_SCALE
    local strip_top = AREA_HEIGHT * 0.5 - Consts.PANEL_TEXT_INPUT_HEIGHT - 2 * Consts.PADDING
    lines = lines_of(sample)
    test.assert_eq(#lines, 7)
    test.assert_true(lines[7][3] + line_height <= strip_top - Consts.PADDING, "the last line ends above the strip")
    test.assert_true(lines[7][3] + 2 * line_height > strip_top - Consts.PADDING, "another would not")
    finish(s)
end)

test.case("the area shows a font with the component and its reset unlinks the field and forgets the face", function()
    local s = setup()
    s.form:show()
    s.area:show_medium(media.Type.FONT, fonts.reference(s.file), s.file)
    ---@diagnostic disable-next-line: invisible
    local preview = s.area._preview
    assert(preview and get_class_of(preview) == PreviewFontArea)
    ---@cast preview PreviewFontArea
    local _, _, input = parts(preview)
    s.form:focus(input)
    test.assert_true(s.keyboard.text_input)
    local reference = fonts.reference(s.file)

    s.area:reset()
    test.assert_false(lifetime.alive(preview))
    test.assert_false(lifetime.alive(input))
    test.assert_false(s.keyboard.text_input, "the field lost the focus")
    ---@diagnostic disable-next-line: invisible
    test.assert_deep_eq(s.form._inputs, {}, "the field left the form")
    test.assert_deep_eq(s.area.content_parent:get_children(), {})
    local made = s.log.fonts_made
    test.assert_true(fonts.reference(s.file) ~= reference, "the face was forgotten")
    test.assert_eq(s.log.fonts_made, made + 1)
    finish(s)
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Consts = require("app.consts")
local Control = require("controls.control")
local WatchOverlay = require("ui.watch-overlay")
local lifetime = require("lifetime")

---@param scale number The root's
---@return AppMock
local function install(scale)
    mocks.ensure_love_graphics()
    mocks.ensure_love_math()
    local app_mock = mocks.install_app()
    local root = Control()
    root:set_scale(scale)
    app_mock.root = root
    return app_mock
end

---@param overlay WatchOverlay
---@return Control[]
local function line_controls(overlay)
    ---@type Control[]
    local lines = {}
    for i, child in ipairs(overlay:get_children()) do
        if i > 1 then
            table.insert(lines, child)
        end
    end
    return lines
end

test.suite("WatchOverlay")

test.case("is hidden at first and scaled like the root, following its resizes", function()
    local app_mock = install(0.4)
    local overlay = WatchOverlay()
    test.assert_false(overlay:is_visible())
    test.assert_eq(overlay:get_scale(), 0.4)
    test.assert_deep_eq({
        overlay:get_position()
    }, {
        0,
        0
    })
    assert(app_mock.root):set_scale(0.75)
    app_mock.resize_manager.resized:trigger(2000, 1000)
    test.assert_eq(overlay:get_scale(), 0.75)
end)

test.case("the toggle key shows and hides it, other keys do nothing", function()
    local app_mock = install(1)
    local overlay = WatchOverlay()
    app_mock.keyboard_manager:dispatch_key_pressed(Consts.TOGGLE_WATCH_OVERLAY_KEY)
    test.assert_true(overlay:is_visible())
    app_mock.keyboard_manager:dispatch_key_pressed("a")
    test.assert_true(overlay:is_visible())
    app_mock.keyboard_manager:dispatch_key_pressed(Consts.TOGGLE_WATCH_OVERLAY_KEY)
    test.assert_false(overlay:is_visible())
end)

test.case("one text per line, stacked under each other on the background, which fits them", function()
    install(1)
    local overlay = WatchOverlay()
    test.assert_deep_eq({
        overlay:get_size()
    }, {
        0,
        0
    }, "no lines")
    overlay:set_lines({
        "a: 1",
        "long: 2"
    })
    test.assert_deep_eq(overlay:get_lines(), {
        "a: 1",
        "long: 2"
    })
    local first, second = unpack(line_controls(overlay))
    local padding = Consts.WATCH_OVERLAY_PADDING
    local first_w, first_h = first:get_outer_size()
    local second_w, second_h = second:get_outer_size()
    test.assert_deep_eq({
        first:get_position()
    }, {
        padding,
        padding
    })
    test.assert_deep_eq({
        second:get_position()
    }, {
        padding,
        padding + first_h
    })
    test.assert_eq(first:get_scale(), Consts.WATCH_OVERLAY_TEXT_SCALE)
    local w, h = overlay:get_size()
    test.assert_true(w >= math.max(first_w, second_w) + 2 * padding, "fits the widest line")
    test.assert_near(h, first_h + second_h + 2 * padding)
    local background = overlay:get_children()[1]
    test.assert_deep_eq({
        background:get_size()
    }, {
        w,
        h
    })
end)

test.case("the lines follow what is set: a changed one is the same text, a dropped one is destroyed", function()
    install(1)
    local overlay = WatchOverlay()
    overlay:set_lines({
        "a: 1",
        "b: 2"
    })
    local first, second = unpack(line_controls(overlay))
    overlay:set_lines({
        "a: 3"
    })
    test.assert_deep_eq(overlay:get_lines(), {
        "a: 3"
    })
    test.assert_eq(line_controls(overlay)[1], first)
    test.assert_false(lifetime.alive(second))
    overlay:set_lines({})
    test.assert_deep_eq(overlay:get_lines(), {})
    test.assert_false(lifetime.alive(first))
end)

test.case("a line is one line of valid UTF-8, cut at its length limit", function()
    install(1)
    local overlay = WatchOverlay()
    local limit = Consts.WATCH_OVERLAY_MAX_LINE_LENGTH
    overlay:set_lines({
        "t: {\n    a = 1,\n\tb = 2,\n}",
        "bad: \255\254 ok",
        "ł: " .. string.rep("ż", limit),
        string.rep("x", limit)
    })
    test.assert_deep_eq(overlay:get_lines(), {
        "t: { a = 1, b = 2, }",
        "bad: ?? ok",
        "ł: " .. string.rep("ż", limit - 3) .. "...",
        string.rep("x", limit)
    })
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Consts = require("app.consts")
local Control = require("controls.control")
local MonitorScreen = require("screens.monitor-screen")
local MonitorTarget = require("app.monitor-target")
local lifetime = require("lifetime")

---@class TestMonitorTargetCall
---@field chunk string The evaluated chunk, or the added watch's expression
---@field on_reply MonitorReplyHandler

---@class TestMonitorTarget: MonitorTarget
---@field state MonitorTargetState
---@field watches table<string, MonitorWatch>
---@field changes integer
---@field evaluations TestMonitorTargetCall[]
---@field added_watches TestMonitorTargetCall[]
local TestMonitorTarget = class("TestMonitorTarget", MonitorTarget)

---@param name string
function TestMonitorTarget:init(name)
    MonitorTarget.init(self, name, "127.0.0.1", "9400")
    self.state = "connecting"
    self.watches = {}
    self.changes = 0
    self.evaluations = {}
    self.added_watches = {}
end

---@return MonitorTargetState
function TestMonitorTarget:get_state()
    return self.state
end

---@return table<string, MonitorWatch>
function TestMonitorTarget:get_watches()
    return table.copy(self.watches)
end

---@return integer
function TestMonitorTarget:get_revision()
    return MonitorTarget.get_revision(self) + self.changes
end

---@param state MonitorTargetState
function TestMonitorTarget:set_state(state)
    self.state = state
    self.changes = self.changes + 1
end

---@param name string
---@param value string|nil `nil` removes the watch
function TestMonitorTarget:set_watch(name, value)
    self.watches[name] = value and {
        value = value,
        frame = 1,
        time = 0
    } or nil
    self.changes = self.changes + 1
end

---@param chunk string
---@param on_reply MonitorReplyHandler
function TestMonitorTarget:evaluate(chunk, on_reply)
    table.insert(self.evaluations, {
        chunk = chunk,
        on_reply = on_reply
    })
end

---@param expr string
---@param on_reply MonitorReplyHandler|nil
function TestMonitorTarget:add_watch(expr, on_reply)
    table.insert(self.added_watches, {
        chunk = expr,
        on_reply = assert(on_reply)
    })
end

---@class TestMonitorScreenSide
---@field app AppMock
---@field screen MonitorScreen
---@field client TestMonitorTarget
---@field server TestMonitorTarget

---@return TestMonitorScreenSide
local function show_screen()
    mocks.ensure_love_graphics()
    mocks.ensure_love_math()
    local app_mock = mocks.install_app()
    app_mock.root = Control()
    app_mock.width, app_mock.height = 2000, 1500
    local client, server = TestMonitorTarget("client"), TestMonitorTarget("server")
    local screen = MonitorScreen({
        client,
        server
    })
    screen:show()
    return {
        app = app_mock,
        screen = screen,
        client = client,
        server = server
    }
end

---@param side TestMonitorScreenSide
local function frame(side)
    side.app.update_event:trigger(1 / 60)
end

---@param side TestMonitorScreenSide
---@param text string
local function enter(side, text)
    side.screen:get_input():set_text(text)
    side.app.text_event_manager:key_pressed("return")
end

---@param side TestMonitorScreenSide
---@param ctrl Control
local function click(side, ctrl)
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    local manager = side.app.button_event_manager
    manager:dispatch_pointer_move(x, y, 1)
    manager:dispatch_pointer_down(x, y, 1)
    manager:dispatch_pointer_up(x, y, 1)
end

---@param side TestMonitorScreenSide
local function finish(side)
    lifetime.destroy(side.screen)
end

test.suite("MonitorScreen")

test.case("a button per target with its name and state, the selected one in the hover color", function()
    local side = show_screen()
    local buttons = side.screen:get_buttons()
    test.assert_eq(#buttons, 2)
    test.assert_eq(buttons[1]:get_text(), "client: connecting")
    test.assert_eq(buttons[2]:get_text(), "server: connecting")
    test.assert_eq(side.screen:get_selected(), side.client)
    test.assert_deep_eq(buttons[1]:get_color(), Consts.BUTTON_HOVER_COLOR)
    test.assert_deep_eq(buttons[2]:get_color(), Consts.BUTTON_NORMAL_COLOR)
    local x1 = buttons[1]:get_position()
    local x2 = buttons[2]:get_position()
    test.assert_true(x2 > x1 + buttons[1]:get_outer_size(), "side by side")
    side.server:set_state("connected")
    frame(side)
    test.assert_eq(buttons[2]:get_text(), "server: connected")
    finish(side)
end)

test.case("the watch lines follow the selected target's watches, sorted by name, one line each", function()
    local side = show_screen()
    test.assert_deep_eq(side.screen:get_watch_lines(), {})
    side.client:set_watch("time", "1.5")
    side.client:set_watch("pos", "{\n    1,\n    2,\n}")
    frame(side)
    test.assert_deep_eq(side.screen:get_watch_lines(), {
        "pos: { 1, 2, }",
        "time: 1.5"
    })
    side.client:set_watch("time", "2")
    side.client:set_watch("pos", nil)
    side.server:set_watch("other", "x")
    frame(side)
    test.assert_deep_eq(side.screen:get_watch_lines(), {
        "time: 2"
    })
    finish(side)
end)

test.case("the log lines follow the selected target's log, kept scrolled to the newest", function()
    local side = show_screen()
    side.client:append_log("first")
    side.client:append_log("bad \255 byte")
    side.client:append_log("   1.000      client-main\t> padded")
    frame(side)
    test.assert_deep_eq(side.screen:get_log_lines(), {
        "first",
        "bad ? byte",
        " 1.000 client-main > padded"
    })
    for i = 1, Consts.MONITOR_LOG_LINES do
        side.client:append_log("line " .. i)
    end
    frame(side)
    local lines = side.screen:get_log_lines()
    test.assert_eq(#lines, Consts.MONITOR_LOG_LINES)
    test.assert_eq(lines[1], "line 1")
    test.assert_eq(lines[#lines], "line " .. Consts.MONITOR_LOG_LINES)
    ---@diagnostic disable-next-line: invisible
    local view = side.screen._log.view
    local _, max_y = view:get_max_scroll()
    local _, y = view:get_scroll()
    test.assert_true(max_y > 0, "the log overflows")
    test.assert_eq(y, max_y)
    view:set_scroll(0, 0)
    side.client:append_log("one more")
    frame(side)
    local _, kept = view:get_scroll()
    test.assert_eq(kept, 0, "a log scrolled back stays where it is")
    finish(side)
end)

test.case("Enter evaluates the line on the selected target, logs its reply after >, and clears the field", function()
    local side = show_screen()
    test.assert_true(side.screen:get_input():is_focused(), "the line has the focus")
    enter(side, "return 1 + 1")
    test.assert_eq(side.screen:get_input():get_text(), "")
    test.assert_eq(#side.client.evaluations, 1)
    test.assert_eq(side.client.evaluations[1].chunk, "return 1 + 1")
    side.client.evaluations[1].on_reply(true, "2")
    enter(side, "error('no')")
    side.client.evaluations[2].on_reply(false, "no\nstack traceback:")
    frame(side)
    test.assert_deep_eq(side.screen:get_log_lines(), {
        "> 2",
        "> no",
        "> stack traceback:"
    })
    enter(side, "   ")
    test.assert_eq(#side.client.evaluations, 2, "a blank line evaluates nothing")
    finish(side)
end)

test.case("a line starting with = adds the rest as a watch, logging only an error", function()
    local side = show_screen()
    enter(side, "=app:get_time()")
    test.assert_eq(side.screen:get_input():get_text(), "")
    test.assert_eq(#side.client.evaluations, 0)
    test.assert_eq(side.client.added_watches[1].chunk, "app:get_time()")
    side.client.added_watches[1].on_reply(true, "")
    enter(side, "=)")
    side.client.added_watches[2].on_reply(false, "unexpected symbol")
    frame(side)
    test.assert_deep_eq(side.screen:get_log_lines(), {
        "> unexpected symbol"
    })
    finish(side)
end)

test.case("a click on a target's button selects it: its watches, its log and its evaluations", function()
    local side = show_screen()
    side.client:set_watch("a", "1")
    side.client:append_log("client line")
    side.server:set_watch("b", "2")
    side.server:append_log("server line")
    frame(side)
    local buttons = side.screen:get_buttons()
    click(side, buttons[2])
    test.assert_eq(side.screen:get_selected(), side.server)
    frame(side)
    test.assert_deep_eq(side.screen:get_watch_lines(), {
        "b: 2"
    })
    test.assert_deep_eq(side.screen:get_log_lines(), {
        "server line"
    })
    test.assert_deep_eq(buttons[2]:get_color(), Consts.BUTTON_HOVER_COLOR)
    side.app.button_event_manager:dispatch_pointer_move(0, 0, nil)
    frame(side)
    test.assert_deep_eq(buttons[1]:get_color(), Consts.BUTTON_NORMAL_COLOR)
    enter(side, "return 3")
    test.assert_eq(#side.server.evaluations, 1)
    test.assert_eq(#side.client.evaluations, 0)
    finish(side)
end)

test.case("a resize lays the panes out side by side and keeps the line's text and focus", function()
    local side = show_screen()
    side.screen:get_input():set_text("typed")
    side.app.width, side.app.height = 1000, 800
    side.screen:on_resize(1000, 800)
    local input = side.screen:get_input()
    test.assert_eq(input:get_size(), 1000 - 2 * Consts.PADDING)
    test.assert_eq(input:get_text(), "typed")
    test.assert_true(input:is_focused())
    ---@diagnostic disable-next-line: invisible
    local watches, log = side.screen._watches.view, side.screen._log.view
    local wx = watches:get_position()
    local lx = log:get_position()
    local ww = watches:get_size()
    test.assert_eq(wx, Consts.PADDING)
    test.assert_eq(lx, 2 * Consts.PADDING + ww)
    test.assert_eq(lx + log:get_size(), 1000 - Consts.PADDING)
    enter(side, "return 1")
    test.assert_eq(#side.client.evaluations, 1, "Enter reaches the new line alone")
    test.assert_eq(side.client.evaluations[1].chunk, "return 1")
    finish(side)
end)

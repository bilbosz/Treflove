local test = require("tests.lib.test")
local ConsoleApp = require("app.console-app")
local ConsoleSession = require("utils.console-session")
local console_socket = require("tests.lib.console-socket")

local frame = console_socket.frame

---@class TestConsoleAppWorld
---@field socket TestFakeSocket
---@field queue love.Event[] The events `love.event.poll` gives next
---@field pumps integer Calls of `love.event.pump`
---@field lines string[] Every output line, `err: ` before an error's
---@field input string What stdin holds
---@field reads integer Reads of stdin

---@class TestConsoleApp: ConsoleApp
---@field world TestConsoleAppWorld
local TestConsoleApp = class("TestConsoleApp", ConsoleApp)

---@param params ArgParserResult
---@param world TestConsoleAppWorld
function TestConsoleApp:init(params, world)
    ConsoleApp.init(self, params, function()
        return world.socket
    end)
    self.world = world
end

---@protected
---@param line string
---@param is_error boolean
function TestConsoleApp:output(line, is_error)
    table.insert(self.world.lines, (is_error and "err: " or "") .. line)
end

---@protected
---@return string
function TestConsoleApp:read_input()
    self.world.reads = self.world.reads + 1
    return self.world.input
end

---@param world TestConsoleAppWorld
---@return love.event
local function make_event_module(world)
    ---@class TestConsoleEventModule: love.event
    local event_module = {}

    function event_module.pump()
        world.pumps = world.pumps + 1
    end

    ---@return MainLoopEventIterator
    function event_module.poll()
        return function()
            return table.remove(world.queue, 1)
        end
    end

    return event_module
end

---@param fields {chunk: string|nil, follow: boolean|nil, watch: string|nil}
---@return ArgParserResult
local function console_params(fields)
    return {
        app_type = "console",
        address = "127.0.0.1",
        port = "9391",
        headless = false,
        chunk = fields.chunk,
        follow = fields.follow == true,
        watch = fields.watch
    }
end

---@param name string
---@param fn fun(world: TestConsoleAppWorld)
local function app_case(name, fn)
    test.case(name, function()
        local previous_event, previous_run, previous_errorhandler = love.event, love.run, love.errorhandler
        local step_timeout = ConsoleApp.STEP_TIMEOUT
        ConsoleApp.STEP_TIMEOUT = 0
        ---@type TestConsoleAppWorld
        local world = {
            socket = console_socket.make(),
            queue = {},
            pumps = 0,
            lines = {},
            input = "",
            reads = 0
        }
        love.event = make_event_module(world)
        ---@type boolean, any
        local ok, err = pcall(fn, world)
        love.event, love.run, love.errorhandler = previous_event, previous_run, previous_errorhandler
        ConsoleApp.STEP_TIMEOUT = step_timeout
        if not ok then
            error(err, 0)
        end
    end)
end

---@param world TestConsoleAppWorld
---@param params ArgParserResult
---@return fun(): integer|nil iterate
local function run(world, params)
    TestConsoleApp(params, world):install()
    return love.run()
end

---@param iterate fun(): integer|nil
---@param n integer
local function iterate_running(iterate, n)
    for i = 1, n do
        test.assert_eq(iterate(), nil, "ended at iteration " .. i)
    end
end

test.suite("ConsoleApp")

app_case("love.run sends the chunk, and the loop pumps the events every iteration and ends with the reply's code", function(world)
    local iterate = run(world, console_params({
        chunk = "return 1 + 1"
    }))
    test.assert_eq(world.socket.sent, frame("eval", "return 1 + 1"))
    test.assert_eq(world.reads, 0, "stdin is left alone with a chunk")
    iterate_running(iterate, 2)
    test.assert_eq(world.pumps, 2)
    world.socket.arriving = {
        frame("ok", "2")
    }
    test.assert_eq(iterate(), ConsoleSession.EXIT_OK)
    test.assert_deep_eq(world.lines, {
        "2"
    })
    test.assert_true(world.socket.closed)
end)

app_case("an error reply ends the loop with 1 and goes to the error output", function(world)
    local iterate = run(world, console_params({
        chunk = "error('x')"
    }))
    world.socket.arriving = {
        frame("error", "console:1: x")
    }
    test.assert_eq(iterate(), ConsoleSession.EXIT_ERROR)
    test.assert_deep_eq(world.lines, {
        "err: console:1: x"
    })
end)

app_case("without a chunk, stdin is read once before the loop and sent", function(world)
    world.input = "return 2 + 2\n"
    local iterate = run(world, console_params({}))
    test.assert_eq(world.reads, 1)
    test.assert_eq(world.socket.sent, frame("eval", "return 2 + 2\n"))
    world.socket.arriving = {
        frame("ok", "4")
    }
    test.assert_eq(iterate(), ConsoleSession.EXIT_OK)
    test.assert_eq(world.reads, 1)
end)

app_case("a refused connection ends the first iteration with 2, the reason on the error output", function(world)
    world.socket.refuse = true
    local iterate = run(world, console_params({
        chunk = "return 1"
    }))
    test.assert_eq(iterate(), ConsoleSession.EXIT_FAILURE)
    test.assert_eq(#world.lines, 1)
    test.assert_true(world.lines[1]:find("^err: cannot connect to the console at 127.0.0.1:9391") ~= nil, world.lines[1])
end)

app_case("following a watch, the frames are output until a quit event ends the loop with 2", function(world)
    local iterate = run(world, console_params({
        watch = "math.floor(app:get_time())"
    }))
    test.assert_eq(world.reads, 0, "a watch reads no stdin")
    test.assert_eq(world.socket.sent, frame("eval", ConsoleSession.watch_chunk("math.floor(app:get_time())")))
    world.socket.arriving = {
        frame("ok", "") .. frame("watch", "t\t60\t1\t1"),
        frame("watch", "t\t120\t2\t2")
    }
    iterate_running(iterate, 3)
    test.assert_deep_eq(world.lines, {
        "t\t60\t1\t1",
        "t\t120\t2\t2"
    })
    world.queue = {
        "quit"
    }
    test.assert_eq(iterate(), ConsoleSession.EXIT_FAILURE)
    test.assert_true(world.socket.closed)
end)

app_case("following, the connection closing after the reply ends the loop with 0", function(world)
    local iterate = run(world, console_params({
        chunk = "log(true)",
        follow = true
    }))
    world.socket.arriving = {
        frame("ok", "") .. frame("log", "a line")
    }
    iterate_running(iterate, 1)
    world.socket.peer_closed = true
    test.assert_eq(iterate(), ConsoleSession.EXIT_OK)
    test.assert_deep_eq(world.lines, {
        "a line"
    })
end)

app_case("a quit event before a one-shot reply ends the loop with the session's code, 2", function(world)
    local iterate = run(world, console_params({
        chunk = "return 1"
    }))
    world.queue = {
        "quit"
    }
    test.assert_eq(iterate(), ConsoleSession.EXIT_FAILURE)
    test.assert_deep_eq(world.lines, {})
end)

app_case("the error handler writes the error with a traceback to the error output", function(world)
    run(world, console_params({
        chunk = "return 1"
    }))
    love.errorhandler("boom")
    test.assert_eq(#world.lines, 1)
    test.assert_true(world.lines[1]:find("^err: boom\nstack traceback:") ~= nil, world.lines[1])
end)

local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Console = require("app.console")
local MainLoop = require("app.main-loop")
local Control = require("controls.control")
local Event = require("events.event")
local Logger = require("utils.logger")
local ScenarioRunner = require("app.scenario-runner")

---@class TestMainLoop: MainLoop
---@field calls string[] Every pause, resume and step, in order
---@field frame integer What `get_frame` says
local TestMainLoop = class("TestMainLoop", MainLoop)

function TestMainLoop:init()
    MainLoop.init(self, true)
    self.calls = {}
    self.frame = 0
end

function TestMainLoop:pause()
    MainLoop.pause(self)
    table.insert(self.calls, "pause")
end

function TestMainLoop:resume()
    MainLoop.resume(self)
    table.insert(self.calls, "resume")
end

---@param n integer
function TestMainLoop:step(n)
    MainLoop.step(self, n)
    table.insert(self.calls, "step " .. n)
end

---@return integer
function TestMainLoop:get_frame()
    return self.frame
end

---@return TestConsoleStream
local function make_stream()
    ---@class TestConsoleStream: ConsoleStream
    ---@field buffer string Arrived from the client, not yet received
    ---@field peer_closed boolean The client closed: once the buffer is empty, `receive` says "closed"
    ---@field send_limit integer|nil At most this many bytes per `send`, the rest timing out
    ---@field sent string Everything sent, not yet taken by `take_frames`
    ---@field closed boolean
    ---@field timeouts (number|nil)[]
    local stream = {
        buffer = "",
        peer_closed = false,
        send_limit = nil,
        sent = "",
        closed = false,
        timeouts = {}
    }

    ---@param value number|nil
    function stream:settimeout(value)
        table.insert(self.timeouts, value)
    end

    ---@param data string
    ---@param i integer|nil
    ---@return integer|nil, string|nil, integer|nil
    function stream:send(data, i)
        i = i or 1
        local j = #data
        if self.send_limit then
            j = math.min(j, i + self.send_limit - 1)
        end
        self.sent = self.sent .. string.sub(data, i, j)
        if j < #data then
            return nil, "timeout", j
        end
        return j, nil, nil
    end

    ---@param pattern "*l"|integer
    ---@return string|nil, string|nil, string|nil
    function stream:receive(pattern)
        assert(type(pattern) == "number", "the console receives bytes")
        if #self.buffer >= pattern then
            local data = string.sub(self.buffer, 1, pattern)
            self.buffer = string.sub(self.buffer, pattern + 1)
            return data, nil, nil
        end
        local partial = self.buffer
        self.buffer = ""
        return nil, self.peer_closed and "closed" or "timeout", partial
    end

    function stream:close()
        self.closed = true
    end

    return stream
end

---@return TestConsoleListener
local function make_listener()
    ---@class TestConsoleListener: ConsoleListener
    ---@field waiting TestConsoleStream[] Accepted one by one
    ---@field timeout number|nil
    local listener = {
        waiting = {},
        timeout = nil
    }

    ---@return ConsoleStream|nil, string|nil
    function listener:accept()
        local stream = table.remove(self.waiting, 1)
        if stream then
            return stream, nil
        end
        return nil, "timeout"
    end

    ---@param value number|nil
    function listener:settimeout(value)
        self.timeout = value
    end

    function listener:close()
    end

    return listener
end

---@param kind string
---@param body string
---@return string
local function frame(kind, body)
    return string.format("%s %d\n%s", kind, #body, body)
end

---@param stream TestConsoleStream
---@return string[][] Each `{kind, body}` sent since the last call
local function take_frames(stream)
    ---@type string[][]
    local frames = {}
    local sent = stream.sent
    while sent ~= "" do
        local kind, length, rest = string.match(sent, "^(%l+) (%d+)\n(.*)$")
        assert(kind, "a malformed frame was sent")
        local n = assert(tonumber(length))
        table.insert(frames, {
            kind,
            string.sub(rest, 1, n)
        })
        sent = string.sub(rest, n + 1)
    end
    stream.sent = ""
    return frames
end

---@class TestConsoleSide
---@field app AppMock
---@field loop TestMainLoop
---@field listener TestConsoleListener
---@field console Console
---@field quits (integer|nil)[] The exit code of every `app:quit`
---@field bound {host: string, port: integer}|nil

---@param root Control|nil The app's root, with a window
---@return TestConsoleSide
local function make_console(root)
    local app_mock = mocks.install_app()
    local loop = TestMainLoop()
    local listener = make_listener()
    ---@type (integer|nil)[]
    local quits = {}
    ---@type {host: string, port: integer}|nil
    local bound = nil
    app_mock.service_event = Event()
    app_mock.main_loop = loop
    app_mock.root = root
    app_mock.overlay = nil
    ---@param exit_code integer|nil
    function app_mock:quit(exit_code)
        table.insert(quits, exit_code or -1)
    end
    local console = Console("9391", function(host, port)
        bound = {
            host = host,
            port = port
        }
        return listener, nil
    end)
    return {
        app = app_mock,
        loop = loop,
        listener = listener,
        console = console,
        quits = quits,
        bound = bound
    }
end

---@param side TestConsoleSide
---@return TestConsoleStream
local function connect(side)
    local stream = make_stream()
    table.insert(side.listener.waiting, stream)
    return stream
end

---@param side TestConsoleSide
local function service(side)
    side.app.service_event:trigger()
end

---@param side TestConsoleSide
---@param stream TestConsoleStream
---@param chunk string
---@return string[][] The frames sent back in that service
local function eval(side, stream, chunk)
    stream.buffer = stream.buffer .. frame("eval", chunk)
    service(side)
    return take_frames(stream)
end

---@param side TestConsoleSide
---@return ScenarioRunner
local function make_runner(side)
    mocks.ensure_love_math()
    side.app.params = {
        app_type = "client",
        address = "localhost",
        port = "8080",
        headless = true,
        follow = false
    }
    local runner = ScenarioRunner()
    side.app.scenario_runner = runner
    return runner
end

---@param side TestConsoleSide
---@param n integer
local function updates(side, n)
    for _ = 1, n do
        side.app.update_event:trigger(1 / 60)
    end
end

---@param chunk string
---@return string An eval chunk running `chunk` as a peer
local function run_chunk(chunk)
    return string.format("run(%q)", chunk)
end

test.suite("Console")

test.case("listens on 127.0.0.1 and the port, without blocking", function()
    local side = make_console()
    test.assert_deep_eq(side.bound, {
        host = "127.0.0.1",
        port = 9391
    })
    test.assert_eq(side.listener.timeout, 0)
    test.assert_true(side.console:is_listening())
    local stream = connect(side)
    service(side)
    test.assert_deep_eq(stream.timeouts, {
        0
    })
end)

test.case("a port that cannot be bound is logged and the console stays inert", function()
    local app_mock = mocks.install_app()
    app_mock.service_event = Event()
    local console = Console("9391", function()
        return nil, "address already in use"
    end)
    test.assert_false(console:is_listening())
    test.assert_deep_eq(app_mock.logs, {
        {
            "console: cannot listen on 127.0.0.1:9391: address already in use"
        }
    })
    test.assert_eq(app_mock.service_event:get_handler(console), nil)
end)

test.case("an eval replies ok with every return value, a table serialized, joined by tabs", function()
    local side = make_console()
    local stream = connect(side)
    test.assert_deep_eq(eval(side, stream, "return 1, 'a', nil, {b = 2}"), {
        {
            "ok",
            "1\ta\tnil\t{\n    b = 2,\n}"
        }
    })
    test.assert_deep_eq(eval(side, stream, "local x = 1"), {
        {
            "ok",
            ""
        }
    }, "no return value")
end)

test.case("a raised error replies with its message and a traceback, a syntax error with its message", function()
    local side = make_console()
    local stream = connect(side)
    local frames = eval(side, stream, "local x = 1\nerror('boom')")
    test.assert_eq(#frames, 1)
    test.assert_eq(frames[1][1], "error")
    test.assert_eq(string.match(frames[1][2], "^[^\n]*"), "console:2: boom")
    test.assert_true(string.find(frames[1][2], "stack traceback:", 1, true), "the traceback")
    frames = eval(side, stream, "return return")
    test.assert_eq(frames[1][1], "error")
    test.assert_true(string.find(frames[1][2], "^console:1: "), "the syntax error")
end)

test.case("the chunks share globals of their own over _G", function()
    local side = make_console()
    local stream = connect(side)
    eval(side, stream, "console_test_value = 5")
    test.assert_deep_eq(eval(side, stream, "return console_test_value, type(string.format)"), {
        {
            "ok",
            "5\tfunction"
        }
    })
    test.assert_eq(_G["console_test_value"], nil)
end)

test.case("a frame split across services runs once it is whole, and frames arriving together reply in order", function()
    local side = make_console()
    local stream = connect(side)
    local data = frame("eval", "return 'hello\\nworld'")
    stream.buffer = string.sub(data, 1, 3)
    service(side)
    stream.buffer = stream.buffer .. string.sub(data, 4, 12)
    service(side)
    test.assert_deep_eq(take_frames(stream), {})
    stream.buffer = stream.buffer .. string.sub(data, 13) .. frame("eval", "return 2") .. "eval 8\nret"
    service(side)
    test.assert_deep_eq(take_frames(stream), {
        {
            "ok",
            "hello\nworld"
        },
        {
            "ok",
            "2"
        }
    })
    stream.buffer = stream.buffer .. "urn 3"
    service(side)
    test.assert_deep_eq(take_frames(stream), {
        {
            "ok",
            "3"
        }
    })
end)

test.case("each client gets its own replies", function()
    local side = make_console()
    local a, b = connect(side), connect(side)
    a.buffer = frame("eval", "return 'a'")
    b.buffer = frame("eval", "return 'b'")
    service(side)
    test.assert_deep_eq(take_frames(a), {
        {
            "ok",
            "a"
        }
    })
    test.assert_deep_eq(take_frames(b), {
        {
            "ok",
            "b"
        }
    })
end)

test.case("a watch reports its first value and every change to every client, an unchanged one never", function()
    local side = make_console()
    local hp = 10
    side.console:add_function("hp", function()
        return hp
    end)
    local a, b = connect(side), connect(side)
    side.loop.frame = 7
    side.app:advance_time(0.5)
    test.assert_deep_eq(eval(side, a, "watch('hp', function() return hp() end)"), {
        {
            "ok",
            ""
        },
        {
            "watch",
            "hp\t7\t0.500\t10"
        }
    })
    test.assert_deep_eq(take_frames(b), {
        {
            "watch",
            "hp\t7\t0.500\t10"
        }
    })
    side.loop.frame = 8
    service(side)
    test.assert_deep_eq(take_frames(a), {}, "unchanged")
    hp = 9
    service(side)
    test.assert_deep_eq(take_frames(a), {
        {
            "watch",
            "hp\t8\t0.500\t9"
        }
    })
    test.assert_deep_eq(take_frames(b), {
        {
            "watch",
            "hp\t8\t0.500\t9"
        }
    })
end)

test.case("a watch set again reports its value again; a raising one reports the error's message", function()
    local side = make_console()
    local stream = connect(side)
    eval(side, stream, "watch('t', function() return {1} end)")
    test.assert_deep_eq(eval(side, stream, "watch('t', function() return {1} end)"), {
        {
            "ok",
            ""
        },
        {
            "watch",
            "t\t0\t0.000\t{\n    1,\n}"
        }
    })
    test.assert_deep_eq(eval(side, stream, "watch('e', function() error('broken', 0) end)"), {
        {
            "ok",
            ""
        },
        {
            "watch",
            "e\t0\t0.000\tbroken"
        }
    })
end)

test.case("unwatch ends a watch, watches names those left, sorted", function()
    local side = make_console()
    local value = 1
    side.console:add_function("value", function()
        return value
    end)
    local stream = connect(side)
    eval(side, stream, "watch('b', value) watch('a', value) watch('c', value)")
    test.assert_deep_eq(eval(side, stream, "return unwatch('b'), unwatch('x')"), {
        {
            "ok",
            "true\tfalse"
        }
    })
    test.assert_deep_eq(eval(side, stream, "return watches()"), {
        {
            "ok",
            "{\n    \"a\",\n    \"c\",\n}"
        }
    })
    value = 2
    service(side)
    test.assert_deep_eq(take_frames(stream), {
        {
            "watch",
            "a\t0\t0.000\t2"
        },
        {
            "watch",
            "c\t0\t0.000\t2"
        }
    })
end)

test.case("a watch's name is a non-empty string without a tab or a line break", function()
    local side = make_console()
    local stream = connect(side)
    for _, chunk in ipairs({
        "watch('', print)",
        "watch('a\\tb', print)",
        "watch('a\\nb', print)",
        "watch(1, print)",
        "watch('a', 1)"
    }) do
        test.assert_eq(eval(side, stream, chunk)[1][1], "error", chunk)
    end
end)

test.case("a client that connects later gets every evaluated watch at its first service, with its last value, frame and time", function()
    local side = make_console()
    local hp = 10
    side.console:add_function("hp", function()
        return hp
    end)
    local first = connect(side)
    side.loop.frame = 3
    side.app:advance_time(0.25)
    eval(side, first, "watch('hp', hp) watch('b', function() return 'x' end)")
    hp = 9
    side.loop.frame = 4
    service(side)
    take_frames(first)
    side.loop.frame = 9
    side.app:advance_time(1)
    local late = connect(side)
    service(side)
    test.assert_deep_eq(take_frames(late), {
        {
            "watch",
            "b\t3\t0.250\tx"
        },
        {
            "watch",
            "hp\t4\t0.250\t9"
        }
    })
    test.assert_deep_eq(take_frames(first), {}, "the others hear nothing again")
    service(side)
    test.assert_deep_eq(take_frames(late), {}, "once")
end)

test.case("a watch not evaluated yet when a client connects reaches it once, at its first evaluation", function()
    local side = make_console()
    local first = connect(side)
    service(side)
    local late = connect(side)
    eval(side, first, "watch('w', function() return 1 end)")
    test.assert_deep_eq(take_frames(late), {
        {
            "watch",
            "w\t0\t0.000\t1"
        }
    })
end)

test.case("pause, frames and resume reach the main loop; frames pauses only a running loop", function()
    local side = make_console()
    local stream = connect(side)
    eval(side, stream, "frames(2)")
    test.assert_deep_eq(side.loop.calls, {
        "pause",
        "step 2"
    })
    eval(side, stream, "frames(1)")
    eval(side, stream, "resume() pause() resume()")
    test.assert_deep_eq(side.loop.calls, {
        "pause",
        "step 2",
        "step 1",
        "resume",
        "pause",
        "resume"
    })
    test.assert_eq(eval(side, stream, "frames(0)")[1][1], "error")
end)

test.case("quit asks the app to quit with the exit code and resumes the loop", function()
    local side = make_console()
    local stream = connect(side)
    eval(side, stream, "pause()")
    test.assert_deep_eq(eval(side, stream, "quit(3)"), {
        {
            "ok",
            ""
        }
    })
    eval(side, stream, "quit()")
    test.assert_deep_eq(side.quits, {
        3,
        -1
    })
    test.assert_deep_eq(side.loop.calls, {
        "pause",
        "resume",
        "resume"
    })
end)

test.case("log streams the app's log lines to the client that asked, until it stops or leaves", function()
    local side = make_console()
    local a, b = connect(side), connect(side)
    local logger = Logger({
        start_time = 0
    }, "console-test")
    eval(side, a, "log(true)")
    logger:log("streamed line")
    service(side)
    local frames = take_frames(a)
    test.assert_eq(#frames, 1)
    test.assert_eq(frames[1][1], "log")
    test.assert_true(string.find(frames[1][2], "console-test", 1, true), frames[1][2])
    test.assert_eq(string.sub(frames[1][2], -#"> streamed line"), "> streamed line")
    test.assert_deep_eq(take_frames(b), {}, "a client that did not ask")
    eval(side, a, "log(false)")
    logger:log("not streamed")
    service(side)
    test.assert_deep_eq(take_frames(a), {})
    eval(side, b, "log()")
    b.peer_closed = true
    service(side)
    test.assert_true(b.closed)
    logger:log("nobody listens")
    service(side)
    test.assert_deep_eq(take_frames(a), {})
    Logger.set_sink(nil)
end)

test.case("add_function gives the chunks a function of their own", function()
    local side = make_console()
    local stream = connect(side)
    side.console:add_function("double", function(x)
        return 2 * x
    end)
    test.assert_deep_eq(eval(side, stream, "return double(21)"), {
        {
            "ok",
            "42"
        }
    })
end)

test.case("a malformed header closes its client and is logged; the others go on", function()
    for _, data in ipairs({
        "hello\n",
        "eval x\n",
        "ok 1\nx",
        string.rep("e", 65)
    }) do
        local side = make_console()
        local bad, good = connect(side), connect(side)
        bad.buffer = data
        good.buffer = frame("eval", "return 1")
        service(side)
        test.assert_true(bad.closed, data)
        test.assert_eq(#side.app.logs, 2, data)
        test.assert_deep_eq(take_frames(good), {
            {
                "ok",
                "1"
            }
        })
    end
end)

test.case("a body over 1 MiB closes its client", function()
    local side = make_console()
    local stream = connect(side)
    stream.buffer = string.format("eval %d\n", 1024 * 1024 + 1)
    service(side)
    test.assert_true(stream.closed)
    local fitting = connect(side)
    fitting.buffer = string.format("eval %d\nreturn 1--", 1024 * 1024)
    service(side)
    test.assert_false(fitting.closed, "a body of 1 MiB")
end)

test.case("a send that does not go through goes on in the next services", function()
    local side = make_console()
    local stream = connect(side)
    stream.send_limit = 4
    stream.buffer = frame("eval", "return 'abcdef'")
    service(side)
    test.assert_eq(stream.sent, "ok 6")
    for _ = 1, 3 do
        service(side)
    end
    test.assert_deep_eq(take_frames(stream), {
        {
            "ok",
            "abcdef"
        }
    })
end)

test.case("a client that leaves too much unsent is closed", function()
    local side = make_console()
    local stream = connect(side)
    stream.send_limit = 0
    local limit = Console.SEND_BUFFER_LIMIT
    Console.SEND_BUFFER_LIMIT = 100
    eval(side, stream, "return string.rep('x', 50)")
    test.assert_false(stream.closed)
    eval(side, stream, "return string.rep('x', 50)")
    Console.SEND_BUFFER_LIMIT = limit
    test.assert_true(stream.closed)
end)

test.case("screenshot captures the frame into the save directory, and raises without a window", function()
    mocks.ensure_love_math()
    local previous_graphics, previous_filesystem = love.graphics, love.filesystem
    ---@type string[]
    local captured = {}
    ---@class TestScreenshotGraphics: love.graphics
    local graphics = {}
    ---@param name string
    function graphics.captureScreenshot(name)
        table.insert(captured, name)
    end
    ---@class TestSaveDirectoryFilesystem: love.filesystem
    local filesystem = {}
    ---@return string
    function filesystem.getSaveDirectory()
        return "/save"
    end
    love.graphics, love.filesystem = graphics, filesystem

    local side = make_console(Control())
    local stream = connect(side)
    test.assert_deep_eq(eval(side, stream, "return screenshot('shot.png')"), {
        {
            "ok",
            "/save/shot.png"
        }
    })
    test.assert_deep_eq(captured, {
        "shot.png"
    })
    local headless = make_console()
    local other = connect(headless)
    test.assert_eq(eval(headless, other, "return screenshot('shot.png')")[1][1], "error")

    love.graphics, love.filesystem = previous_graphics, previous_filesystem
end)

test.case("with a window the watches show on the overlay", function()
    mocks.ensure_love_graphics()
    mocks.ensure_love_math()
    local side = make_console(Control())
    local overlay = assert(side.console:get_overlay())
    test.assert_eq(side.app.overlay, overlay)
    local stream = connect(side)
    local value = "x"
    side.console:add_function("value", function()
        return value
    end)
    eval(side, stream, "watch('v', value) watch('n', function() return 1 end)")
    test.assert_deep_eq(overlay:get_lines(), {
        "n: 1",
        "v: x"
    })
    value = "y"
    eval(side, stream, "unwatch('n')")
    test.assert_deep_eq(overlay:get_lines(), {
        "v: y"
    })
end)

test.case("run replies once its run passes, with the chunk's return values serialized as an eval's, and never quits", function()
    local side = make_console()
    local runner = make_runner(side)
    local stream = connect(side)
    test.assert_deep_eq(eval(side, stream, run_chunk("driver:frames(2) return 1, {a = 2}, steps.LOGIN, driver.headless")), {})
    test.assert_true(runner:is_running())
    updates(side, 2)
    service(side)
    test.assert_deep_eq(take_frames(stream), {}, "the run is waiting its frames")
    updates(side, 1)
    test.assert_false(runner:is_running())
    service(side)
    test.assert_deep_eq(take_frames(stream), {
        {
            "ok",
            "1\t{\n    a = 2,\n}\tadam\ttrue"
        }
    })
    test.assert_eq(assert(runner:get_result()).name, "peer")
    test.assert_deep_eq(side.quits, {}, "a headless run started by the console leaves the program running")
end)

test.case("a failing run replies error with the message and the traceback of the run", function()
    local side = make_console()
    make_runner(side)
    local stream = connect(side)
    eval(side, stream, run_chunk("driver:frames(1)\ndriver:expect(false, 'nope')"))
    updates(side, 2)
    service(side)
    local frames = take_frames(stream)
    test.assert_eq(#frames, 1)
    test.assert_eq(frames[1][1], "error")
    test.assert_eq(string.find(frames[1][2], "peer:2: nope\nstack traceback:\n", 1, true), 1, frames[1][2])
end)

test.case("no frame is taken from a client while its run is pending; the next eval is answered after the run's reply", function()
    local side = make_console()
    make_runner(side)
    local stream = connect(side)
    ---@type string[]
    local marks = {}
    side.console:add_function("mark", function(name)
        table.insert(marks, name)
    end)
    local other = connect(side)
    stream.buffer = frame("eval", run_chunk("driver:frames(1) return 'ran'")) .. frame("eval", "mark('after') return 'next'")
    service(side)
    test.assert_deep_eq(eval(side, other, "mark('other') return 'other'"), {
        {
            "ok",
            "other"
        }
    }, "another client is answered meanwhile")
    test.assert_deep_eq(marks, {
        "other"
    })
    test.assert_deep_eq(take_frames(stream), {})
    updates(side, 2)
    test.assert_deep_eq(marks, {
        "other"
    }, "the eval waits in the buffer")
    service(side)
    test.assert_deep_eq(take_frames(stream), {
        {
            "ok",
            "ran"
        },
        {
            "ok",
            "next"
        }
    })
    test.assert_deep_eq(marks, {
        "other",
        "after"
    })
end)

test.case("run raises while the runner is busy, on a compile error and without a runner", function()
    local side = make_console()
    local runner = make_runner(side)
    local a, b = connect(side), connect(side)
    eval(side, a, run_chunk("driver:frames(1)"))
    local frames = eval(side, b, run_chunk("return 1"))
    test.assert_eq(frames[1][1], "error")
    test.assert_true(string.find(frames[1][2], "a scenario is running", 1, true), frames[1][2])
    updates(side, 2)
    service(side)
    test.assert_deep_eq(take_frames(a), {
        {
            "ok",
            ""
        }
    }, "the busy runner's run replies as it would")
    frames = eval(side, b, run_chunk("return return"))
    test.assert_eq(frames[1][1], "error")
    test.assert_eq(string.find(frames[1][2], "peer:1: "), 1, frames[1][2])
    test.assert_false(runner:is_running())
    side.app.scenario_runner = nil
    frames = eval(side, b, run_chunk("return 1"))
    test.assert_eq(frames[1][1], "error")
    test.assert_true(string.find(frames[1][2], "run needs a scenario runner", 1, true), frames[1][2])
end)

test.case("a chunk that raises after its run started replies its error alone; the run goes on silently", function()
    local side = make_console()
    local runner = make_runner(side)
    local stream = connect(side)
    local frames = eval(side, stream, run_chunk("driver:frames(1) return 'ran'") .. " error('after')")
    test.assert_eq(#frames, 1)
    test.assert_eq(frames[1][1], "error")
    test.assert_true(runner:is_running())
    test.assert_deep_eq(eval(side, stream, "return 2"), {
        {
            "ok",
            "2"
        }
    })
    updates(side, 2)
    test.assert_true(assert(runner:get_result()).ok)
    service(side)
    test.assert_deep_eq(take_frames(stream), {})
end)

test.case("a client that closes while its run is pending drops the reply; the run goes on", function()
    local side = make_console()
    local runner = make_runner(side)
    local stream = connect(side)
    eval(side, stream, run_chunk("driver:frames(2) return 'ran'"))
    stream.peer_closed = true
    service(side)
    test.assert_true(stream.closed)
    test.assert_true(runner:is_running())
    updates(side, 3)
    test.assert_true(assert(runner:get_result()).ok)
    service(side)
    test.assert_eq(stream.sent, "")
end)

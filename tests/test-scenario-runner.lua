local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Control = require("controls.control")
local ScenarioRunner = require("app.scenario-runner")
local ScreenManager = require("screens.screen-manager")

---@class TestRunnerWorld
---@field app AppMock
---@field runner ScenarioRunner
---@field exit_codes integer[] The argument of every `app:quit`
---@field closed boolean The server console's socket was closed
---@field previous_filesystem love.filesystem|nil

---@type table<string, string> The scenario files, by name
local SCENARIOS = {
    pass = "return function(driver) driver:frames(2) driver:log('done') end",
    fail = "return function(driver)\n    driver:frames(1)\n    driver:expect(false, 'boom')\nend",
    quit = "return function(driver) driver:quit(3) end",
    console = "return function(driver) driver:server('return 1') end",
    broken = "return function(driver",
    nothing = "return 42",
    shaped = "return {peers = {'bob', 'eve'}, run = function(driver) driver:frames(1) driver:log('shaped') end}",
    alone = "return {run = function(driver) driver:log('alone') end}",
    runless = "return {peers = {'bob'}}",
    badpeers = "return {peers = {'bob', 3}, run = function() end}",
    fixtured = "return {fixture = 'old-town', run = function(driver) driver:log('fixtured') end}",
    badfixture = "return {fixture = {'old-town'}, run = function() end}"
}

---@param headless boolean
---@return TestRunnerWorld
local function setup(headless)
    local app_mock = mocks.install_app()
    mocks.ensure_love_math()
    ---@type table<string, string>
    local files = {}
    for name, content in pairs(SCENARIOS) do
        files["scenarios/" .. name .. ".lua"] = content
    end
    local previous_filesystem = mocks.install_love_filesystem(files)
    ---@class TestRunnerFilesystem: love.filesystem
    local filesystem = setmetatable({}, {
        __index = love.filesystem
    })
    ---@param path string
    ---@return function|nil, string|nil
    function filesystem.load(path)
        return loadstring(assert(files[path]), "@" .. path)
    end
    love.filesystem = filesystem
    ---@type TestRunnerWorld
    local world
    ---@class TestRunnerSocket: ConsoleSocket
    local socket = {}
    ---@return integer|nil, string|nil
    function socket:connect()
        return 1, nil
    end
    function socket:settimeout()
    end
    ---@param data string
    ---@return integer|nil, string|nil, integer|nil
    function socket:send(data)
        return #data, nil, nil
    end
    ---@param pattern "*l"|integer
    ---@return string|nil, string|nil, string|nil
    function socket:receive(pattern)
        return pattern == "*l" and "ok 1" or "1", nil, nil
    end
    function socket:close()
        world.closed = true
    end
    app_mock.params = {
        app_type = "client",
        address = "localhost",
        port = "8080",
        server_console = "9191",
        headless = headless,
        follow = false
    }
    app_mock.root = Control()
    app_mock.screen_manager = ScreenManager()
    world = {
        app = app_mock,
        runner = ScenarioRunner(function()
            return socket
        end),
        exit_codes = {},
        closed = false,
        previous_filesystem = previous_filesystem
    }
    ---@param exit_code integer|nil
    function app_mock:quit(exit_code)
        table.insert(world.exit_codes, exit_code)
    end
    return world
end

---@param world TestRunnerWorld
local function finish(world)
    mocks.restore_love_filesystem(world.previous_filesystem)
end

---@param world TestRunnerWorld
---@param n integer
local function updates(world, n)
    for _ = 1, n do
        world.app.update_event:trigger(1 / 60)
    end
end

---@param world TestRunnerWorld
---@return string[] The first argument of every log line
local function log_lines(world)
    local lines = {}
    for _, entry in ipairs(world.app.logs) do
        table.insert(lines, tostring(entry[1]))
    end
    return lines
end

test.suite("ScenarioRunner")

test.case("a scenario runs one step per update from the next one on and passes when it returns, quitting headless when asked", function()
    local world = setup(true)
    world.runner:start("pass", true)
    test.assert_true(world.runner:is_running())
    test.assert_eq(world.runner:get_result(), nil)
    updates(world, 2)
    test.assert_true(world.runner:is_running(), "two frames yielded")
    updates(world, 1)
    test.assert_false(world.runner:is_running())
    test.assert_deep_eq(world.runner:get_result(), {
        name = "pass",
        ok = true
    })
    test.assert_deep_eq(log_lines(world), {
        "scenario pass: started",
        "scenario: done",
        "scenario pass: passed"
    })
    test.assert_deep_eq(world.exit_codes, {
        0
    }, "a headless run quits with success")
    updates(world, 1)
    test.assert_eq(#world.exit_codes, 1, "an idle runner does nothing")
    finish(world)
end)

test.case("a headless run started without quitting at its end logs its outcome and leaves the program running", function()
    local world = setup(true)
    world.runner:start("pass")
    updates(world, 3)
    test.assert_true(assert(world.runner:get_result()).ok)
    test.assert_eq(log_lines(world)[3], "scenario pass: passed")
    world.runner:start("fail", false)
    updates(world, 2)
    test.assert_false(assert(world.runner:get_result()).ok)
    test.assert_eq(log_lines(world)[5]:find("scenario fail: failed: ", 1, true), 1)
    test.assert_deep_eq(world.exit_codes, {})
    finish(world)
end)

test.case("a scenario that raises fails with its error, logged with the traceback and the control dump", function()
    local world = setup(true)
    world.runner:start("fail", true)
    updates(world, 2)
    local result = assert(world.runner:get_result())
    test.assert_false(result.ok)
    test.assert_eq(result.name, "fail")
    test.assert_eq(result.error, "scenarios/fail.lua:3: boom")
    local line = log_lines(world)[2]
    test.assert_eq(line:find("scenario fail: failed: scenarios/fail.lua:3: boom\nstack traceback:\n", 1, true), 1, line)
    test.assert_true(line:find("\nControl[eva]\n", 1, true) ~= nil, "the dump: " .. line)
    test.assert_deep_eq(world.exit_codes, {
        1
    })
    finish(world)
end)

test.case("in a window the app stays as it is at the end", function()
    local world = setup(false)
    world.runner:start("fail", true)
    updates(world, 2)
    test.assert_false(assert(world.runner:get_result()).ok)
    world.runner:start("pass", true)
    updates(world, 3)
    test.assert_true(assert(world.runner:get_result()).ok, "another run once the first ended")
    test.assert_deep_eq(world.exit_codes, {})
    finish(world)
end)

test.case("a scenario that quits keeps its exit code", function()
    local world = setup(true)
    world.runner:start("quit", true)
    updates(world, 1)
    test.assert_true(assert(world.runner:get_result()).ok)
    test.assert_deep_eq(world.exit_codes, {
        3,
        3
    })
    finish(world)
end)

test.case("a missing, broken or functionless scenario file fails its run", function()
    local world = setup(true)
    world.runner:start("missing", true)
    test.assert_true(world.runner:is_running(), "the file is loaded by the first update")
    updates(world, 1)
    test.assert_eq(assert(world.runner:get_result()).error, "no scenario scenarios/missing.lua")
    world.runner:start("broken", true)
    updates(world, 1)
    test.assert_true(assert(assert(world.runner:get_result()).error):find("scenarios/broken.lua:1:", 1, true) ~= nil)
    world.runner:start("nothing", true)
    updates(world, 1)
    test.assert_eq(assert(world.runner:get_result()).error, "scenarios/nothing.lua returns no function and no table")
    test.assert_deep_eq(world.exit_codes, {
        1,
        1,
        1
    })
    finish(world)
end)

test.case("a scenario file may return a table with its run function and, optionally, its peers and its fixture", function()
    local world = setup(true)
    world.runner:start("shaped", true)
    updates(world, 2)
    test.assert_true(assert(world.runner:get_result()).ok)
    world.runner:start("alone", true)
    updates(world, 1)
    test.assert_true(assert(world.runner:get_result()).ok)
    world.runner:start("fixtured", true)
    updates(world, 1)
    test.assert_true(assert(world.runner:get_result()).ok)
    test.assert_deep_eq(log_lines(world), {
        "scenario shaped: started",
        "scenario: shaped",
        "scenario shaped: passed",
        "scenario alone: started",
        "scenario: alone",
        "scenario alone: passed",
        "scenario fixtured: started",
        "scenario: fixtured",
        "scenario fixtured: passed"
    })
    finish(world)
end)

test.case("a table without a run function, with peers that are not a list of strings or a fixture that is not a string, fails its run", function()
    local world = setup(true)
    world.runner:start("runless", true)
    updates(world, 1)
    test.assert_eq(assert(world.runner:get_result()).error, "scenarios/runless.lua returns a table without a run function")
    world.runner:start("badpeers", true)
    updates(world, 1)
    test.assert_eq(assert(world.runner:get_result()).error, "scenarios/badpeers.lua returns peers that are not a list of strings")
    world.runner:start("badfixture", true)
    updates(world, 1)
    test.assert_eq(assert(world.runner:get_result()).error, "scenarios/badfixture.lua returns a fixture that is not a string")
    test.assert_deep_eq(world.exit_codes, {
        1,
        1,
        1
    })
    finish(world)
end)

test.case("start_function runs a function as a scenario and calls on_end once, after the outcome is logged, with its return values", function()
    local world = setup(true)
    ---@type any[][]
    local ends = {}
    ---@type ScenarioDriver|nil
    local seen = nil
    world.runner:start_function("probe", function(driver)
        seen = driver
        driver:frames(1)
        return 1, nil, {
            a = 2
        }
    end, false, function(result, ...)
        table.insert(ends, {
            result,
            select("#", ...),
            ...
        })
        test.assert_eq(log_lines(world)[2], "scenario probe: passed", "logged first")
        test.assert_false(world.runner:is_running(), "the run is over")
    end)
    test.assert_true(world.runner:is_running())
    updates(world, 1)
    test.assert_true(seen ~= nil, "the function got the driver")
    test.assert_deep_eq(ends, {})
    updates(world, 3)
    test.assert_deep_eq(ends, {
        {
            {
                name = "probe",
                ok = true
            },
            3,
            1,
            nil,
            {
                a = 2
            }
        }
    })
    test.assert_deep_eq(world.exit_codes, {}, "a run not asked to quit leaves the program running")
    finish(world)
end)

test.case("on_end gets a failed run's result alone, with the error and its traceback", function()
    local world = setup(true)
    ---@type ScenarioResult[]
    local results = {}
    ---@type integer[]
    local counts = {}
    world.runner:start_function("probe", function()
        error("boom", 0)
    end, false, function(result, ...)
        table.insert(results, result)
        table.insert(counts, select("#", ...))
    end)
    updates(world, 2)
    test.assert_eq(#results, 1)
    test.assert_deep_eq(counts, {
        0
    })
    local result = results[1]
    test.assert_false(result.ok)
    test.assert_eq(result.error, "boom")
    local traceback = assert(result.traceback)
    test.assert_eq(traceback:find("boom\nstack traceback:\n", 1, true), 1, traceback)
    test.assert_eq(result, world.runner:get_result())
    finish(world)
end)

test.case("one scenario at a time", function()
    local world = setup(true)
    world.runner:start("pass")
    test.assert_error(function()
        world.runner:start("pass")
    end)
    test.assert_error(function()
        world.runner:start_function("probe", function()
        end)
    end)
    updates(world, 3)
    finish(world)
end)

test.case("the end of a run closes the driver's server console", function()
    local world = setup(true)
    world.runner:start("console")
    updates(world, 1)
    test.assert_true(assert(world.runner:get_result()).ok)
    test.assert_true(world.closed)
    finish(world)
end)

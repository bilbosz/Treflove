local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Sandbox = require("scripting.sandbox")

local Failure = Sandbox.Failure

---A limit a looping script hits within a fraction of a second
local SHORT_TIME_LIMIT = 0.05

---How long a run under `SHORT_TIME_LIMIT` may take at most, with the hook's period and the test's own work
local TIME_LIMIT_SLACK = 1

test.suite("Sandbox")

test.case("runs a script and returns its values", function()
    mocks.install_app()
    local sandbox = Sandbox()
    local result = sandbox:run("local a, b = ... return 1 + 2, 'x', nil, true")
    test.assert_true(result.ok)
    test.assert_eq(result.failure, nil)
    test.assert_eq(result.message, nil)
    test.assert_deep_eq(result.values, {
        3,
        "x",
        nil,
        true
    })
end)

test.case("reports a syntax error with the chunk name", function()
    mocks.install_app()
    local result = Sandbox():run("return 1 +", "rules")
    test.assert_false(result.ok)
    test.assert_eq(result.failure, Failure.SYNTAX)
    test.assert_true(string.find(result.message, "^rules:1:"), result.message)
    test.assert_deep_eq(result.values, {})
end)

test.case("reports a runtime error with the chunk name and line", function()
    mocks.install_app()
    local result = Sandbox():run("local t = nil\nreturn t.x", "rules")
    test.assert_false(result.ok)
    test.assert_eq(result.failure, Failure.RUNTIME)
    test.assert_true(string.find(result.message, "^rules:2:"), result.message)
    local raised = Sandbox():run("error({code = 7})")
    test.assert_eq(raised.failure, Failure.RUNTIME)
    test.assert_true(string.find(raised.message, "^table:"), raised.message)
    test.assert_true(string.find(Sandbox():run("return 1 +", "a/b.lua").message, "^a/b.lua:1:"))
    test.assert_true(string.find(Sandbox():run("error('bad')").message, "^script:1: bad"))
end)

test.case("refuses a binary chunk", function()
    mocks.install_app()
    local result = Sandbox():run(string.dump(function()
        return 1
    end), "compiled")
    test.assert_false(result.ok)
    test.assert_eq(result.failure, Failure.SYNTAX)
    test.assert_true(string.find(result.message, "^compiled:"), result.message)
end)

test.case("the scripts of one sandbox share their globals, two sandboxes do not", function()
    mocks.install_app()
    local a = Sandbox()
    local b = Sandbox()
    test.assert_true(a:run("counter = 1 function bump() counter = counter + 1 return counter end").ok)
    test.assert_deep_eq(a:run("return bump()").values, {
        2
    })
    test.assert_eq(a:get_environment().counter, 2)
    test.assert_deep_eq(b:run("return counter, bump").values, {})
    test.assert_eq(b:get_environment().counter, nil)
end)

test.case("the host's data is the script's globals", function()
    mocks.install_app()
    local world = {
        tokens = {
            "a"
        }
    }
    local sandbox = Sandbox({
        world = world,
        double = function(x)
            return 2 * x
        end
    })
    local result = sandbox:run("world.tokens[2] = 'b' return double(#world.tokens)")
    test.assert_deep_eq(result.values, {
        4
    })
    test.assert_deep_eq(world.tokens, {
        "a",
        "b"
    })
end)

test.case("print goes to the app's log by default, and to the output when one is given", function()
    local app_mock = mocks.install_app()
    test.assert_true(Sandbox():run("print('hello', 1)").ok)
    test.assert_deep_eq(app_mock.logs[#app_mock.logs], {
        "hello\t1"
    })
    ---@type string[]
    local lines = {}
    local sandbox = Sandbox(nil, {
        output = function(line)
            table.insert(lines, line)
        end
    })
    test.assert_true(sandbox:run("print('a') print('b', nil)").ok)
    test.assert_deep_eq(lines, {
        "a",
        "b\tnil"
    })
end)

test.case("the standard library does not reach the host", function()
    mocks.install_app()
    local sandbox = Sandbox()
    test.assert_deep_eq(sandbox:run("return getmetatable(''), rawget(_G, 'os').exit, string.dump, loadstring, require, io, debug").values, {})
    test.assert_eq(sandbox:run("os.exit(1)").failure, Failure.RUNTIME)
    test.assert_eq(sandbox:run("table.from_string('return 1')").failure, Failure.RUNTIME)
    test.assert_eq(sandbox:run("string.format('%s', app)").failure, nil)
    test.assert_deep_eq(sandbox:run("return tostring(app), tostring(love)").values, {
        "nil",
        "nil"
    })
end)

---@param sandbox Sandbox
---@param source string
---@return ScriptResult, number
local function run_timed(sandbox, source)
    local start = os.clock()
    local result = sandbox:run(source)
    return result, os.clock() - start
end

test.case("an endless loop is stopped by the time limit", function()
    mocks.install_app()
    local sandbox = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    local result, elapsed = run_timed(sandbox, "while true do end")
    test.assert_false(result.ok)
    test.assert_eq(result.failure, Failure.TIME)
    test.assert_true(string.find(result.message, "CPU time"), result.message)
    test.assert_true(elapsed < TIME_LIMIT_SLACK, "stopped in " .. elapsed .. " s")
    test.assert_true(sandbox:run("return 1").ok, "the sandbox is usable after")
end)

test.case("a loop the JIT would compile is stopped too", function()
    mocks.install_app()
    local sandbox = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    local result, elapsed = run_timed(sandbox, "local n = 0 for i = 1, 1e12 do n = n + i end return n")
    test.assert_eq(result.failure, Failure.TIME)
    test.assert_true(elapsed < TIME_LIMIT_SLACK, "stopped in " .. elapsed .. " s")
    local nested, nested_elapsed = run_timed(sandbox, "local function f() local n = 0 for i = 1, 1e12 do n = n + i end return n end return f()")
    test.assert_eq(nested.failure, Failure.TIME)
    test.assert_true(nested_elapsed < TIME_LIMIT_SLACK, "stopped in " .. nested_elapsed .. " s")
end)

test.case("pcall does not swallow the interruption", function()
    mocks.install_app()
    local sandbox = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    local result, elapsed = run_timed(sandbox, [[
        while true do
            pcall(function()
                while true do
                    pcall(function()
                        while true do end
                    end)
                end
            end)
        end
    ]])
    test.assert_eq(result.failure, Failure.TIME)
    test.assert_true(elapsed < TIME_LIMIT_SLACK, "stopped in " .. elapsed .. " s")
    local tail = sandbox:run("return pcall(function() while true do end end)")
    test.assert_false(tail.ok, "a tail-called pcall does not hide it")
    test.assert_eq(tail.failure, Failure.TIME)
    test.assert_deep_eq(tail.values, {})
end)

test.case("an xpcall handler does not run past the limit", function()
    mocks.install_app()
    local sandbox = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    local result, elapsed = run_timed(sandbox, [[
        while true do
            xpcall(function() error("x") end, function() while true do end end)
        end
    ]])
    test.assert_eq(result.failure, Failure.TIME)
    test.assert_true(elapsed < TIME_LIMIT_SLACK, "stopped in " .. elapsed .. " s")
end)

test.case("an allocating script is stopped by the memory limit", function()
    mocks.install_app()
    local sandbox = Sandbox(nil, {
        memory_limit = 256
    })
    local result, elapsed = run_timed(sandbox, "local t = {} while true do t[#t + 1] = string.rep('x', 100) .. #t end")
    test.assert_false(result.ok)
    test.assert_eq(result.failure, Failure.MEMORY)
    test.assert_true(string.find(result.message, "256 KB"), result.message)
    test.assert_true(elapsed < TIME_LIMIT_SLACK, "stopped in " .. elapsed .. " s")
    test.assert_true(sandbox:run("local t = {} for i = 1, 100 do t[i] = i end return #t").ok, "a modest script fits")
end)

test.case("string.rep through the method syntax is capped while a script runs", function()
    mocks.install_app()
    local sandbox = Sandbox()
    local result = sandbox:run("return ('x'):rep(2 ^ 21)")
    test.assert_eq(result.failure, Failure.RUNTIME)
    test.assert_true(string.find(result.message, "string.rep", 1, true), result.message)
    test.assert_deep_eq(sandbox:run("return ('ab'):rep(2), ('x'):upper()").values, {
        "abab",
        "X"
    })
    test.assert_eq(#("x"):rep(2 ^ 21), 2 ^ 21, "the host's rep is whole again")
    test.assert_eq(getmetatable("").__index, string)
end)

test.case("the debug hook and the string metatable are restored after every run", function()
    mocks.install_app()
    local function marker()
    end
    debug.sethook(marker, "", 1e9)
    local sandbox = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    test.assert_true(sandbox:run("return 1").ok)
    test.assert_eq(sandbox:run("while true do end").failure, Failure.TIME)
    test.assert_eq(sandbox:run("error('x')").failure, Failure.RUNTIME)
    local hook, mask, count = debug.gethook()
    debug.sethook()
    test.assert_eq(hook, marker)
    test.assert_eq(mask, "")
    test.assert_eq(count, 1e9)
    test.assert_eq(getmetatable("").__index, string)
    test.assert_eq(debug.gethook(), nil)
end)

test.case("call runs a function the script defined under the limits", function()
    mocks.install_app()
    local sandbox = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    test.assert_true(sandbox:run("function tick(dt) return dt * 2, 'ticked' end function spin() while true do end end").ok)
    local env = sandbox:get_environment()
    local result = sandbox:call(env.tick, 21)
    test.assert_true(result.ok)
    test.assert_deep_eq(result.values, {
        42,
        "ticked"
    })
    local start = os.clock()
    local spun = sandbox:call(env.spin)
    test.assert_eq(spun.failure, Failure.TIME)
    test.assert_true(os.clock() - start < TIME_LIMIT_SLACK)
    test.assert_eq(sandbox:call(function()
        error("host side", 0)
    end).message, "host side")
end)

test.case("a run nested in a host function is stopped alone, the outer one goes on", function()
    mocks.install_app()
    local inner = Sandbox(nil, {
        time_limit = SHORT_TIME_LIMIT
    })
    local outer = Sandbox({
        spin_inner = function()
            return inner:run("while true do end").failure
        end
    }, {
        time_limit = 5
    })
    local result, elapsed = run_timed(outer, [[
        local inner_failure = spin_inner()
        local n = 0
        for i = 1, 100000 do n = n + i end
        return inner_failure, n
    ]])
    test.assert_true(result.ok, result.message)
    test.assert_deep_eq(result.values, {
        Failure.TIME,
        5000050000
    })
    test.assert_true(elapsed < TIME_LIMIT_SLACK, "took " .. elapsed .. " s")
    test.assert_eq(debug.gethook(), nil)
end)

test.case("a failing host function is a runtime error of the script", function()
    mocks.install_app()
    local sandbox = Sandbox({
        boom = function()
            error("boom", 0)
        end
    })
    local result = sandbox:run("boom()")
    test.assert_eq(result.failure, Failure.RUNTIME)
    test.assert_eq(result.message, "boom")
end)

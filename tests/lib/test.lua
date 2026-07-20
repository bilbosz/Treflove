---Minimal zero-dependency test framework. Tests are grouped into suites; each
---case runs in protected mode so one failure never stops the run.
---@class TestSuite
---@field name string
---@field passed number
---@field failed number
---@field failures {name: string, err: string}[]
local test = {}

---@type TestSuite[]
local suites = {}

---@type TestSuite|nil
local current_suite = nil

---Start a new suite; subsequent `test.case` calls are recorded under it.
---@param name string
function test.suite(name)
    current_suite = {
        name = name,
        passed = 0,
        failed = 0,
        failures = {}
    }
    table.insert(suites, current_suite)
end

---Run a single test case in protected mode.
---@param name string
---@param fn fun()
function test.case(name, fn)
    local suite = assert(current_suite, "test.suite() must be called before test.case()")
    local ok, err = xpcall(fn, function(e)
        return tostring(e)
    end)
    if ok then
        suite.passed = suite.passed + 1
    else
        suite.failed = suite.failed + 1
        table.insert(suite.failures, {
            name = name,
            err = err
        })
    end
end

---@param value any
---@return string
local function _display(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

---@param actual any
---@param expected any
---@param message string|nil
function test.assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%sexpected %s, got %s", message and (message .. ": ") or "", _display(expected), _display(actual)), 2)
    end
end

---@param value any
---@param message string|nil
function test.assert_true(value, message)
    if not value then
        error(string.format("%sexpected truthy value, got %s", message and (message .. ": ") or "", _display(value)), 2)
    end
end

---@param value any
---@param message string|nil
function test.assert_false(value, message)
    if value then
        error(string.format("%sexpected falsy value, got %s", message and (message .. ": ") or "", _display(value)), 2)
    end
end

---@param actual number
---@param expected number
---@param tolerance number|nil Defaults to 1e-9
---@param message string|nil
function test.assert_near(actual, expected, tolerance, message)
    tolerance = tolerance or 1e-9
    if math.abs(actual - expected) > tolerance then
        error(string.format("%sexpected %s +/- %s, got %s", message and (message .. ": ") or "", tostring(expected), tostring(tolerance), tostring(actual)), 2)
    end
end

---Assert that `fn` raises an error.
---@param fn fun()
---@param message string|nil
function test.assert_error(fn, message)
    local ok = pcall(fn)
    if ok then
        error((message and (message .. ": ") or "") .. "expected an error, but none was raised", 2)
    end
end

---@param a any
---@param b any
---@return boolean
local function _deep_eq(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not _deep_eq(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

---Recursively compare two values (tables by structure, everything else by equality).
---@param actual any
---@param expected any
---@param message string|nil
function test.assert_deep_eq(actual, expected, message)
    if not _deep_eq(actual, expected) then
        error(string.format("%sdeep equality failed:\n  actual:   %s\n  expected: %s", message and (message .. ": ") or "", table.to_string(actual), table.to_string(expected)), 2)
    end
end

---Print results of all suites and return the total number of failed cases.
---@return number
function test.report()
    local total_passed, total_failed = 0, 0
    for _, suite in ipairs(suites) do
        total_passed = total_passed + suite.passed
        total_failed = total_failed + suite.failed
        local status = suite.failed == 0 and "PASS" or "FAIL"
        print(string.format("[%s] %-24s %3d passed, %d failed", status, suite.name, suite.passed, suite.failed))
        for _, failure in ipairs(suite.failures) do
            print(string.format("       * %s\n         %s", failure.name, failure.err))
        end
    end
    print(string.format("Total: %d passed, %d failed", total_passed, total_failed))
    return total_failed
end

return test

local Consts = require("app.consts")
local ScenarioDriver = require("app.scenario-driver")
local Utils = require("utils.utils")
local lifetime = require("lifetime")

---@alias Scenario fun(driver: ScenarioDriver): ...: any

---@class ScenarioFile The table shape of a scenario file
---@field run Scenario
---@field peers string[]|nil The names of the peer clients it drives

---@class ScenarioResult
---@field name string
---@field ok boolean
---@field error string|nil Why the run failed
---@field traceback string|nil The error with the scenario's stack, for a failed run

---@alias ScenarioEndHandler fun(result: ScenarioResult, ...: any) Called with a passing run's return values

---@class ScenarioResults
---@field n integer
---@field [integer] any

---@class ScenarioRunner: Object
---@field private _name string|nil The running scenario's
---@field private _coroutine thread|nil The running scenario, resumed once per update
---@field private _driver ScenarioDriver|nil The running scenario's
---@field private _tcp ConsoleSocketFactory|nil Given to every driver
---@field private _result ScenarioResult|nil The last run's
---@field private _quit_at_end boolean The running scenario's run ends the program when headless
---@field private _on_end ScenarioEndHandler|nil The running scenario's
local ScenarioRunner = class("ScenarioRunner")

---@param ... any
---@return ScenarioResults
local function _pack(...)
    return {
        n = select("#", ...),
        ...
    }
end

---@param list table<any, any>
---@return boolean
local function _is_string_list(list)
    local n = #list
    for k, v in pairs(list) do
        if type(k) ~= "number" or k < 1 or k > n or math.floor(k) ~= k or type(v) ~= "string" then
            return false
        end
    end
    return true
end

---@param path string
---@param scenario any What the file returned
---@return Scenario
local function _get_function(path, scenario)
    if type(scenario) == "function" then
        return scenario
    end
    if type(scenario) ~= "table" then
        error(string.format("%s returns no function and no table", path), 0)
    end
    local file = scenario --[[@as ScenarioFile]]
    if type(file.run) ~= "function" then
        error(string.format("%s returns a table without a run function", path), 0)
    end
    if file.peers ~= nil and (type(file.peers) ~= "table" or not _is_string_list(file.peers)) then
        error(string.format("%s returns peers that are not a list of strings", path), 0)
    end
    return file.run
end

---@param name string
---@return Scenario
local function _load(name)
    local path = string.format("%s/%s.lua", Consts.SCENARIO_DIRECTORY, name)
    if not love.filesystem.getInfo(path, "file") then
        error(string.format("no scenario %s", path), 0)
    end
    local chunk, err = love.filesystem.load(path)
    if not chunk then
        error(err, 0)
    end
    return _get_function(path, chunk())
end

---@param tcp ConsoleSocketFactory|nil What the drivers' server consoles connect with, LuaSocket's by default
function ScenarioRunner:init(tcp)
    self._name = nil
    self._coroutine = nil
    self._driver = nil
    self._tcp = tcp
    self._result = nil
    self._quit_at_end = false
    self._on_end = nil
    app.update_event:register(self, self.on_update)
end

---@param name string A file under `Consts.SCENARIO_DIRECTORY`, without its extension, loaded by the first update
---@param quit_at_end boolean|nil When headless, the end of the run quits with its outcome's exit code: the command line's scenario, not one started on a live program
function ScenarioRunner:start(name, quit_at_end)
    assert_type(name, "string")
    self:start_function(name, function(driver)
        return _load(name)(driver)
    end, quit_at_end)
end

---@param name string What the outcome is logged under
---@param fn Scenario
---@param quit_at_end boolean|nil As `start`'s
---@param on_end ScenarioEndHandler|nil Called once the run ended and its outcome is logged
function ScenarioRunner:start_function(name, fn, quit_at_end, on_end)
    assert_type(name, "string")
    assert_type(fn, "function")
    assert(not self:is_running(), "a scenario is running")
    local driver = ScenarioDriver(self._tcp):attach_lifetime(self)
    self._name = name
    self._driver = driver
    self._quit_at_end = quit_at_end == true
    self._on_end = on_end
    self._coroutine = coroutine.create(function()
        return fn(driver)
    end)
    app:log(string.format("scenario %s: started", name))
end

---@return boolean
function ScenarioRunner:is_running()
    return self._coroutine ~= nil
end

---@return ScenarioResult|nil The last run's, `nil` before the first ends
function ScenarioRunner:get_result()
    return self._result
end

---@param dt number
function ScenarioRunner:on_update(dt)
    local co = self._coroutine
    if not co then
        return
    end
    local results = _pack(coroutine.resume(co))
    if results[1] and coroutine.status(co) ~= "dead" then
        return
    end
    local name, driver = assert(self._name), assert(self._driver)
    if results[1] then
        self:_finish(driver, {
            name = name,
            ok = true
        }, string.format("scenario %s: passed", name), results)
    else
        local message = tostring(results[2])
        local traceback = debug.traceback(co, message)
        local dump = app.root and Utils.dump_controls(app.root) or "no root"
        self:_finish(driver, {
            name = name,
            ok = false,
            error = message,
            traceback = traceback
        }, string.format("scenario %s: failed: %s\n%s", name, traceback, dump), nil)
    end
end

---@private
---@param driver ScenarioDriver
---@param result ScenarioResult
---@param report string
---@param results ScenarioResults|nil What the resume that ended a passing run gave: `true` and the scenario's return values
function ScenarioRunner:_finish(driver, result, report, results)
    local on_end = self._on_end
    self._name = nil
    self._coroutine = nil
    self._driver = nil
    self._on_end = nil
    self._result = result
    local quit = self._quit_at_end and app.params.headless
    self._quit_at_end = false
    app:log(report)
    io.stdout:flush()
    local exit_code = driver:get_exit_code()
    lifetime.destroy(driver)
    if quit then
        app:quit(result.ok and (exit_code or Consts.APP_SUCCESS_EXIT_CODE) or Consts.SCENARIO_FAILURE_EXIT_CODE)
    end
    if on_end then
        if results then
            on_end(result, unpack(results, 2, results.n))
        else
            on_end(result)
        end
    end
end

return ScenarioRunner

local Consts = require("app.consts")
local ScenarioDriver = require("app.scenario-driver")
local Utils = require("utils.utils")
local lifetime = require("lifetime")

---@alias Scenario fun(driver: ScenarioDriver)

---@class ScenarioResult
---@field name string
---@field ok boolean
---@field error string|nil Why the run failed

---@class ScenarioRunner: Object
---@field private _name string|nil The running scenario's
---@field private _coroutine thread|nil The running scenario, resumed once per update
---@field private _driver ScenarioDriver|nil The running scenario's
---@field private _tcp ConsoleSocketFactory|nil Given to every driver
---@field private _result ScenarioResult|nil The last run's
---@field private _quit_at_end boolean The running scenario's run ends the program when headless
local ScenarioRunner = class("ScenarioRunner")

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
    ---@type any What the file returns, a function when it is a scenario
    local scenario = chunk()
    if type(scenario) ~= "function" then
        error(string.format("%s returns no function", path), 0)
    end
    return scenario
end

---@param tcp ConsoleSocketFactory|nil What the drivers' server consoles connect with, LuaSocket's by default
function ScenarioRunner:init(tcp)
    self._name = nil
    self._coroutine = nil
    self._driver = nil
    self._tcp = tcp
    self._result = nil
    self._quit_at_end = false
    app.update_event:register(self, self.on_update)
end

---@param name string A file under `Consts.SCENARIO_DIRECTORY`, without its extension
---@param quit_at_end boolean|nil When headless, the end of the run quits with its outcome's exit code: the command line's scenario, not one started on a live program
function ScenarioRunner:start(name, quit_at_end)
    assert_type(name, "string")
    assert(not self:is_running(), "a scenario is running")
    local driver = ScenarioDriver(self._tcp):attach_lifetime(self)
    self._name = name
    self._driver = driver
    self._quit_at_end = quit_at_end == true
    self._coroutine = coroutine.create(function()
        _load(name)(driver)
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
    ---@type boolean, any
    local ok, err = coroutine.resume(co)
    if ok and coroutine.status(co) ~= "dead" then
        return
    end
    local name, driver = assert(self._name), assert(self._driver)
    if ok then
        self:_finish(driver, {
            name = name,
            ok = true
        }, string.format("scenario %s: passed", name))
    else
        local message = tostring(err)
        local dump = app.root and Utils.dump_controls(app.root) or "no root"
        self:_finish(driver, {
            name = name,
            ok = false,
            error = message
        }, string.format("scenario %s: failed: %s\n%s", name, debug.traceback(co, message), dump))
    end
end

---@private
---@param driver ScenarioDriver
---@param result ScenarioResult
---@param report string
function ScenarioRunner:_finish(driver, result, report)
    self._name = nil
    self._coroutine = nil
    self._driver = nil
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
end

return ScenarioRunner

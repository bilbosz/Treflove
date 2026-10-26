---@class ScenarioPeerRun: Object
---@field private _driver ScenarioDriver The lead's, whose frames `wait` yields
---@field private _name string The peer's
---@field private _console ConsoleClient Connected to the peer's console
---@field private _request ConsoleRequest The `run` sent to the peer
local ScenarioPeerRun = class("ScenarioPeerRun")

---@param driver ScenarioDriver
---@param name string The peer's
---@param console ConsoleClient
---@param request ConsoleRequest
function ScenarioPeerRun:init(driver, name, console, request)
    self._driver = driver
    self._name = name
    self._console = console
    self._request = request
end

---@return boolean The peer's run has ended, or its connection closed
function ScenarioPeerRun:is_done()
    self._console:poll(0)
    return self._request:is_done()
end

---@param timeout number|nil Wall-clock seconds, defaults to `Consts.SCENARIO_WAIT_TIMEOUT`
---@return string The `ok` reply's body: the chunk's return values
function ScenarioPeerRun:wait(timeout)
    local driver, name = self._driver, self._name
    driver:wait_for(function()
        return self:is_done()
    end, timeout, "peer " .. name)
    ---@type boolean, any, any
    local completed, ok, body = pcall(self._request.get_result, self._request)
    driver:expect(completed and ok, string.format("peer %s: %s", name, tostring(completed and body or ok)))
    return body
end

return ScenarioPeerRun

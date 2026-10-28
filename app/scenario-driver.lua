local Consts = require("app.consts")
local ConsoleClient = require("utils.console-client")
local ScenarioPeerRun = require("app.scenario-peer-run")
local Text = require("controls.text")
local TextInput = require("ui.text-input")
local Utils = require("utils.utils")

---@class ScenarioDriver: Object
---@field public headless boolean The run has a fixed frame delta and no window on screen
---@field private _tcp ConsoleSocketFactory|nil What the server's and the peers' console clients connect with, LuaSocket's by default
---@field private _server_console ConsoleClient|nil Connected by the first `server` call
---@field private _peer_consoles table<string, ConsoleClient> By the peer's name, each connected by the first `client` call for its peer
---@field private _exit_code integer|nil What `quit` asked for
local ScenarioDriver = class("ScenarioDriver")

---@type table<string, boolean>
local DRIVER_SOURCES = {
    [debug.getinfo(1, "S").source] = true,
    [debug.getinfo(ScenarioPeerRun.wait, "S").source] = true
}
local UTF8_CHARACTER = "[%z\1-\127\194-\244][\128-\191]*"

---@param message string
local function _fail_at_caller(message)
    local level = 2
    while true do
        local info = debug.getinfo(level, "S")
        if not info or not DRIVER_SOURCES[info.source] then
            break
        end
        level = level + 1
    end
    error(message, level)
end

---@param ctrl Control
---@return string|nil
local function _own_text(ctrl)
    if is_instance_of(ctrl, Text) then
        return (ctrl --[[@as Text]] ):get_text()
    elseif is_instance_of(ctrl, TextInput) then
        return (ctrl --[[@as TextInput]] ):get_text()
    end
    return nil
end

---@param ctrl Control
---@param text string
---@return boolean
local function _has_descendant_text(ctrl, text)
    for _, child in ipairs(ctrl:get_children()) do
        if child:is_visible() then
            if is_instance_of(child, Text) and (child --[[@as Text]] ):get_text() == text or _has_descendant_text(child, text) then
                return true
            end
        end
    end
    return false
end

---@param ctrl Control
---@param text string
---@return boolean The control's own text, or a visible descendant `Text`'s when it has none, is `text`
local function _has_text(ctrl, text)
    local own = _own_text(ctrl)
    if own ~= nil then
        return own == text
    end
    return _has_descendant_text(ctrl, text)
end

---@param tcp ConsoleSocketFactory|nil What `server` and `client` connect with, LuaSocket's `socket.tcp` by default
function ScenarioDriver:init(tcp)
    self.headless = app.params.headless
    self._tcp = tcp
    self._server_console = nil
    self._peer_consoles = {}
    self._exit_code = nil
end

---@param reason lifetime.Reason
function ScenarioDriver:release(reason)
    if reason == "unreachable" or reason == "exit" then
        return
    end
    if self._server_console then
        self._server_console:close()
    end
    for _, console in pairs(self._peer_consoles) do
        console:close()
    end
end

---@generic T
---@param predicate fun(): T|nil|false
---@param timeout number|nil Wall-clock seconds, defaults to `Consts.SCENARIO_WAIT_TIMEOUT`
---@param what string|nil Named in the error
---@return T The predicate's truthy value
function ScenarioDriver:wait_for(predicate, timeout, what)
    local deadline = Utils.get_time() + (timeout or Consts.SCENARIO_WAIT_TIMEOUT)
    local value = predicate()
    while not value do
        if Utils.get_time() >= deadline then
            _fail_at_caller("timed out waiting for " .. (what or "a condition"))
        end
        coroutine.yield()
        value = predicate()
    end
    return value
end

---@param class_name string
---@param timeout number|nil Wall-clock seconds, defaults to `Consts.SCENARIO_WAIT_TIMEOUT`
---@return Screen
function ScenarioDriver:wait_screen(class_name, timeout)
    return assert(self:wait_for(function()
        local screen = self:screen()
        if screen and get_class_name_of(screen) == class_name then
            return screen
        end
        return nil
    end, timeout, class_name))
end

---@param n integer
function ScenarioDriver:frames(n)
    for _ = 1, n do
        coroutine.yield()
    end
end

---@param seconds number Added to the app's clock by the next update
function ScenarioDriver:advance(seconds)
    app.main_loop:skip(seconds)
    coroutine.yield()
end

---@return Screen|nil
function ScenarioDriver:screen()
    return assert(app.screen_manager):get_screen()
end

---@param class_name string
---@param text string|nil
---@param index integer|nil Defaults to 1
---@return Control|nil
function ScenarioDriver:try_find(class_name, text, index)
    local remaining = index or 1
    ---@type Control|nil
    local found = nil
    ---@param ctrl Control
    local function visit(ctrl)
        if found or not ctrl:is_visible() then
            return
        end
        if get_class_name_of(ctrl) == class_name and (text == nil or _has_text(ctrl, text)) then
            remaining = remaining - 1
            if remaining == 0 then
                found = ctrl
                return
            end
        end
        for _, child in ipairs(ctrl:get_children()) do
            visit(child)
        end
    end
    if app.root then
        visit(app.root)
    end
    return found
end

---@param class_name string
---@param text string|nil
---@param index integer|nil Defaults to 1
---@return Control
function ScenarioDriver:find(class_name, text, index)
    local found = self:try_find(class_name, text, index)
    if not found then
        local screen = self:screen()
        _fail_at_caller(string.format("no %s%s%s on %s\n%s", class_name, text and string.format(" with the text %q", text) or "", index and string.format(" #%d", index) or "",
                                      screen and get_class_name_of(screen) or "no screen", app.root and Utils.dump_controls(app.root) or "no root"))
    end
    return assert(found)
end

---@param x number
---@param y number
function ScenarioDriver:move(x, y)
    love.event.push("mousemoved", x, y, 0, 0, false)
end

---@param x number
---@param y number
---@param button integer|nil Defaults to `Consts.LEFT_MOUSE_BUTTON`
function ScenarioDriver:press(x, y, button)
    love.event.push("mousepressed", x, y, button or Consts.LEFT_MOUSE_BUTTON, false, 1)
end

---@param x number
---@param y number
---@param button integer|nil Defaults to `Consts.LEFT_MOUSE_BUTTON`
function ScenarioDriver:release_button(x, y, button)
    love.event.push("mousereleased", x, y, button or Consts.LEFT_MOUSE_BUTTON, false, 1)
end

---@param target Control|string A control, or the class name `find` looks for
---@param text string|nil
---@param index integer|nil
function ScenarioDriver:click(target, text, index)
    local ctrl = type(target) == "string" and self:find(target, text, index) or target --[[@as Control]]
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    self:move(x, y)
    self:press(x, y)
    self:release_button(x, y)
    coroutine.yield()
end

---@param key love.KeyConstant
function ScenarioDriver:key(key)
    love.event.push("keypressed", key, key, false)
    love.event.push("keyreleased", key, key)
    coroutine.yield()
end

---@param key love.KeyConstant Held until `key_up`, so the keyboard manager reads it down (a modifier for the keys and the clicks between)
function ScenarioDriver:key_down(key)
    love.event.push("keypressed", key, key, false)
    coroutine.yield()
end

---@param key love.KeyConstant
function ScenarioDriver:key_up(key)
    love.event.push("keyreleased", key, key)
    coroutine.yield()
end

---@param text string
function ScenarioDriver:type(text)
    for character in string.gmatch(text, UTF8_CHARACTER) do
        love.event.push("textinput", character)
    end
    coroutine.yield()
end

---@param condition any
---@param message string
function ScenarioDriver:expect(condition, message)
    if not condition then
        _fail_at_caller(message)
    end
end

---@param message string
function ScenarioDriver:log(message)
    app:log("scenario: " .. message)
    io.stdout:flush()
end

---@param chunk string Lua run by the server's console
---@return string The `ok` reply's body
function ScenarioDriver:server(chunk)
    if not self._server_console then
        local port = app.params.server_console
        if not port then
            _fail_at_caller("no server console: the client was started without --server-console")
        end
        self._server_console = ConsoleClient(assert(port), nil, self._tcp)
    end
    local ok, body = self._server_console:request(chunk)
    if not ok then
        _fail_at_caller("the server console raised: " .. body)
    end
    return body
end

---@return string[] The names of the peers the command line gave, sorted
function ScenarioDriver:peers()
    ---@type string[]
    local names = {}
    for name in pairs(app.params.peers or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

---@param name string One of `peers()`
---@param chunk string Scenario code the peer runs with `driver` and `steps` in scope
---@return ScenarioPeerRun
function ScenarioDriver:client(name, chunk)
    assert_type(chunk, "string")
    local port = app.params.peers and app.params.peers[name]
    if not port then
        _fail_at_caller("no peer " .. name)
    end
    local console = self._peer_consoles[name]
    if not console then
        console = ConsoleClient(assert(port), nil, self._tcp)
        self._peer_consoles[name] = console
    end
    return ScenarioPeerRun(self, name, console, console:request_async(string.format("run(%q)", chunk)))
end

---@param name string A file name in the save directory, its extension the image format
---@return string The screenshot's absolute path, written once the frame is drawn
function ScenarioDriver:screenshot(name)
    love.graphics.captureScreenshot(name)
    coroutine.yield()
    return love.filesystem.getSaveDirectory() .. "/" .. name
end

---@param exit_code integer|nil Defaults to `Consts.APP_SUCCESS_EXIT_CODE`
function ScenarioDriver:quit(exit_code)
    self._exit_code = exit_code or Consts.APP_SUCCESS_EXIT_CODE
    app:quit(self._exit_code)
end

---@return integer|nil What `quit` asked for, `nil` before it
function ScenarioDriver:get_exit_code()
    return self._exit_code
end

return ScenarioDriver

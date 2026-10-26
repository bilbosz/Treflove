local ConsoleSession = require("utils.console-session")

---@alias ConsoleAppCallbackName "run"|"errorhandler"

---@class ConsoleApp: Object
---@field STEP_TIMEOUT number Seconds one iteration waits for the console between two event pumps; SDL turns SIGINT into a quit event, seen only by a pump
---@field private _params ArgParserResult
---@field private _tcp ConsoleSocketFactory|nil
local ConsoleApp = class("ConsoleApp")

ConsoleApp.STEP_TIMEOUT = 0.05

---@param params ArgParserResult A console's
---@param tcp ConsoleSocketFactory|nil Defaults to LuaSocket's `socket.tcp`
function ConsoleApp:init(params, tcp)
    assert(params.app_type == "console", "the parameters of a console")
    self._params = params
    self._tcp = tcp
end

function ConsoleApp:install()
    -- Through a table: to the language server, a second `function love.run` beside MainLoop's is a duplicate field
    ---@type table<ConsoleAppCallbackName, function>
    local callbacks = love
    callbacks.run = function()
        return self:_start()
    end
    ---@param msg string
    callbacks.errorhandler = function(msg)
        self:output(debug.traceback(tostring(msg), 3), true)
    end
end

---@protected
---@param line string
---@param is_error boolean
function ConsoleApp:output(line, is_error)
    if is_error then
        io.stderr:write(line, "\n")
    else
        print(line)
        io.stdout:flush()
    end
end

---@protected
---@return string
function ConsoleApp:read_input()
    return io.read("*a")
end

---@private
---@return fun(): integer|nil iterate The exit code once the loop ends
function ConsoleApp:_start()
    local params = self._params
    ---@type ConsoleSessionMode
    local mode = {
        chunk = params.chunk,
        follow = params.follow,
        watch = params.watch
    }
    if not mode.chunk and not mode.watch then
        mode.chunk = self:read_input()
    end
    ---@type boolean, ConsoleSession|string
    local connected, session = pcall(function()
        return ConsoleSession(params.address, assert(params.port), mode, function(line, is_error)
            self:output(line, is_error)
        end, self._tcp)
    end)
    if not connected or type(session) == "string" then
        self:output(tostring(session), true)
        return function()
            return ConsoleSession.EXIT_FAILURE
        end
    end
    session:start()
    local following = mode.follow or mode.watch ~= nil
    return function()
        return self:_iterate(session, following)
    end
end

---@private
---@param session ConsoleSession
---@param following boolean
---@return integer|nil exit_code Once the loop ends
function ConsoleApp:_iterate(session, following)
    love.event.pump()
    ---@type MainLoopEventIterator
    local next_event = love.event.poll()
    for name in next_event do
        if name == "quit" then
            session:close()
            return following and ConsoleSession.EXIT_FAILURE or session:get_exit_code()
        end
    end
    if not session:step(ConsoleApp.STEP_TIMEOUT) then
        session:close()
        return session:get_exit_code()
    end
    return nil
end

return ConsoleApp

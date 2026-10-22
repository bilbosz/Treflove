local Consts = require("app.consts")
local environment = require("scripting.environment")

---@class ScriptResult What a run or a call came to
---@field ok boolean
---@field failure Sandbox.Failure|nil Why not, when not `ok`
---@field message string|nil The error message, when not `ok`
---@field values any[] What the chunk or the function returned, when `ok`

---@class Sandbox.Options
---@field time_limit number|nil Seconds of CPU time one run or call may take; `Consts.SCRIPT_TIME_LIMIT` by default
---@field memory_limit number|nil Kilobytes the heap may grow during one run or call; `Consts.SCRIPT_MEMORY_LIMIT` by default
---@field output environment.Output|nil Where the script's `print` writes; the app's log by default

---@class Sandbox.Run One guarded run or call: what its hook checks against, and what it restores
---@field start_clock number
---@field start_memory number
---@field depth number The guard's frame, counted from the bottom of the stack: where an interruption has unwound the script
---@field failure Sandbox.Failure|nil Set by the hook when a limit is hit
---@field hook function|nil The hook set before the run, put back after it
---@field mask string
---@field count number

---Runs untrusted Lua in an environment of its own, under a time and a
---memory limit. The limits are checked between the script's instructions,
---every `Consts.SCRIPT_HOOK_PERIOD` of them, which is why the script's own
---code never runs compiled: the JIT's traces are not interruptible. See
---docs/scripting.md.
---@class Sandbox: Object
---@field private _environment table<string, any>
---@field private _string table<string, any> The environment's `string` library, what the method syntax on strings reaches while a script runs
---@field private _time_limit number
---@field private _memory_limit number
local Sandbox = class("Sandbox")

---@enum Sandbox.Failure
Sandbox.Failure = {
    SYNTAX = "syntax",
    RUNTIME = "runtime",
    TIME = "time",
    MEMORY = "memory"
}
local Failure = Sandbox.Failure

---@type table The error the hook raises; a script cannot name it, and the run records the failure behind it
local INTERRUPTED = {}

---@param line string
local function _log(line)
    app:log(line)
end

---@param data table<string, any>|nil What the host shares with the scripts, as globals; an entry replaces the standard one of its name
---@param options Sandbox.Options|nil
function Sandbox:init(data, options)
    options = options or {}
    self._time_limit = options.time_limit or Consts.SCRIPT_TIME_LIMIT
    self._memory_limit = options.memory_limit or Consts.SCRIPT_MEMORY_LIMIT
    self._environment = environment.create(data or {}, options.output or _log)
    self._string = self._environment.string
end

---@return table<string, any> The script's globals: what a script defined is read here, and run through `call`
function Sandbox:get_environment()
    return self._environment
end

---@param level number A frame, as `debug.getinfo` counts them from the caller of this function: 2 is the caller itself
---@return number How many frames there are from that one down to the bottom of the stack
local function _stack_depth(level)
    local depth = 0
    while debug.getinfo(level + depth, "l") do
        depth = depth + 1
    end
    return depth
end

---@param run Sandbox.Run
local function _restore_hook(run)
    if run.hook then
        debug.sethook(run.hook, run.mask, run.count)
    else
        debug.sethook()
    end
end

---@param run Sandbox.Run
---@return fun()
function Sandbox:_make_hook(run)
    local function hook()
        if run.failure then
            -- Every instruction after the first interruption raises again, so
            -- no pcall of the script keeps it running; the guard's own frame
            -- is where the script is over, and the hook stands down there
            if _stack_depth(3) == run.depth then
                _restore_hook(run)
            else
                error(INTERRUPTED, 0)
            end
            return
        end
        if os.clock() - run.start_clock > self._time_limit then
            run.failure = Failure.TIME
        elseif collectgarbage("count") - run.start_memory > self._memory_limit then
            collectgarbage("collect")
            if collectgarbage("count") - run.start_memory > self._memory_limit then
                run.failure = Failure.MEMORY
            end
        end
        if run.failure then
            debug.sethook(hook, "", 1)
            error(INTERRUPTED, 0)
        end
    end
    return hook
end

---@param ok boolean
---@param ... any
---@return boolean, any[]
local function _collect(ok, ...)
    return ok, {
        ...
    }
end

---@param failure Sandbox.Failure
---@param message string
---@return ScriptResult
local function _failed(failure, message)
    return {
        ok = false,
        failure = failure,
        message = message,
        values = {}
    }
end

---@param fn function
---@param ... any
---@return ScriptResult
function Sandbox:_guard(fn, ...)
    ---@type Sandbox.Run
    local run = {
        start_clock = os.clock(),
        start_memory = collectgarbage("count"),
        depth = _stack_depth(2),
        mask = "",
        count = 0
    }
    run.hook, run.mask, run.count = debug.gethook()
    ---@type {__index: table<string, any>}
    local string_metatable = getmetatable("")
    local previous_index = string_metatable.__index
    string_metatable.__index = self._string
    debug.sethook(self:_make_hook(run), "", Consts.SCRIPT_HOOK_PERIOD)
    local ok, results = _collect(pcall(fn, ...))
    _restore_hook(run)
    string_metatable.__index = previous_index
    if run.failure == Failure.TIME then
        return _failed(run.failure, string.format("The script ran for more than %g s of CPU time", self._time_limit))
    elseif run.failure == Failure.MEMORY then
        return _failed(run.failure, string.format("The script took more than %d KB of memory", self._memory_limit))
    end
    if not ok then
        return _failed(Failure.RUNTIME, tostring(results[1]))
    end
    return {
        ok = true,
        values = results
    }
end

---@param source string Lua source text; a binary chunk is refused
---@param name string|nil Names the chunk in error messages; "script" by default
---@return ScriptResult
function Sandbox:run(source, name)
    assert_type(source, "string")
    name = name or "script"
    if string.sub(source, 1, 1) == "\27" then
        return _failed(Failure.SYNTAX, string.format("%s: a binary chunk is not accepted", name))
    end
    local chunk, syntax_error = loadstring(source, "=" .. name)
    if not chunk then
        return _failed(Failure.SYNTAX, tostring(syntax_error))
    end
    setfenv(chunk, self._environment)
    if jit then
        jit.off(chunk, true)
    end
    return self:_guard(chunk)
end

---Calls a function a script defined, under the limits: a script's function
---called any other way runs with none
---@param fn function
---@param ... any
---@return ScriptResult
function Sandbox:call(fn, ...)
    assert_type(fn, "function")
    return self:_guard(fn, ...)
end

return Sandbox

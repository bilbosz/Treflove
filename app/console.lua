local socket = require("socket")
local Logger = require("utils.logger")
local WatchOverlay = require("ui.watch-overlay")

---@class ConsoleListener The part of a listening LuaSocket TCP object the console uses
---@field accept fun(self: ConsoleListener): ConsoleStream|nil, string|nil A connected client, or `nil` and "timeout" when none is waiting
---@field settimeout fun(self: ConsoleListener, value: number|nil)
---@field close fun(self: ConsoleListener)

---@alias ConsoleBind fun(host: string, port: integer): ConsoleListener|nil, string|nil A listener, or `nil` and the reason

---@alias ConsoleFunction fun(...: any): ...: any

---@class ConsolePeer A connected client
---@field socket ConsoleStream
---@field input string Received, not yet taken by a frame
---@field kind string|nil The kind of the frame whose body is awaited
---@field length integer That body's length
---@field output string Queued, not yet sent
---@field logging boolean The app's log lines go to it
---@field closed boolean
---@field run integer|nil The id of the run whose reply it awaits; no frame of its input is taken meanwhile

---@class ConsoleWatch
---@field fn fun(): ...: any
---@field value string|nil What the last evaluation serialized to, `nil` before the first
---@field frame integer The main loop's frame of that evaluation
---@field time number The app time of that evaluation

---@class ConsoleResults
---@field n integer
---@field [integer] any

---@class Console: Object
---@field HOST string The address the console listens on
---@field MAX_HEADER_LENGTH integer A longer header line is malformed
---@field MAX_BODY_LENGTH integer A longer body closes its client
---@field RECEIVE_SIZE integer Bytes asked of a client's socket per receive
---@field SEND_BUFFER_LIMIT integer A client that leaves more than this unsent is closed
---@field private _listener ConsoleListener|nil `nil` when the port could not be bound
---@field private _peers ConsolePeer[]
---@field private _current ConsolePeer|nil The client whose chunk runs
---@field private _runs integer The runs started so far, the last one's id
---@field private _watches table<string, ConsoleWatch>
---@field private _watch_names string[] Sorted
---@field private _overlay WatchOverlay|nil On `app.overlay`, with a window
---@field private _overlay_stale boolean
---@field private _environment table<string, any> The chunks' globals, over `_G`
---@field private _sink LoggerSink
local Console = class("Console")

Console.HOST = "127.0.0.1"
Console.MAX_HEADER_LENGTH = 64
Console.MAX_BODY_LENGTH = 1024 * 1024
Console.RECEIVE_SIZE = 64 * 1024
Console.SEND_BUFFER_LIMIT = 8 * 1024 * 1024

---@param host string
---@param port integer
---@return ConsoleListener|nil
---@return string|nil
local function _bind(host, port)
    -- The annotations say a server socket; `socket.bind` gives `nil` and the reason on a failure
    local listener, err = socket.bind(host, port)
    return listener --[[@as ConsoleListener|nil]] , err --[[@as string|nil]]
end

---@param ... any
---@return ConsoleResults
local function _pack(...)
    return {
        n = select("#", ...),
        ...
    }
end

---@param value any
---@return string
local function _serialize_value(value)
    if type(value) == "table" then
        ---@type boolean, string
        local ok, text = pcall(table.to_string, value)
        if ok then
            return (string.gsub(text, "^return ", ""))
        end
    end
    ---@type boolean, string
    local ok, text = pcall(tostring, value)
    return ok and text or string.format("<%s>", type(value))
end

---@param results ConsoleResults
---@param first integer The index of the first value
---@return string
local function _serialize(results, first)
    ---@type string[]
    local parts = {}
    for i = first, results.n do
        table.insert(parts, _serialize_value(results[i]))
    end
    return table.concat(parts, "\t")
end

---@param port string
---@param bind ConsoleBind|nil Defaults to LuaSocket's `socket.bind`
function Console:init(port, bind)
    assert_type(port, "string")
    self._listener = nil
    self._peers = {}
    self._current = nil
    self._runs = 0
    self._watches = {}
    self._watch_names = {}
    self._overlay = nil
    self._overlay_stale = false
    self._environment = self:_make_environment()
    self._sink = function(line)
        self:_on_log_line(line)
    end

    local listener, err = (bind or _bind)(Console.HOST, assert(tonumber(port), "the port is a number"))
    if not listener then
        app:log(string.format("console: cannot listen on %s:%s: %s", Console.HOST, port, tostring(err)))
        return
    end
    listener:settimeout(0)
    self._listener = listener
    if app.root then
        self._overlay = WatchOverlay()
        app.overlay = self._overlay
    end
    app.service_event:register(self, self._on_service)
    app:log(string.format("console: listening on %s:%s", Console.HOST, port))
end

---@param name string A global of the chunks
---@param fn ConsoleFunction
function Console:add_function(name, fn)
    assert_type(name, "string")
    assert_type(fn, "function")
    self._environment[name] = fn
end

---@return boolean listening `false` when the port could not be bound
function Console:is_listening()
    return self._listener ~= nil
end

---@return WatchOverlay|nil overlay On `app.overlay`, with a window
function Console:get_overlay()
    return self._overlay
end

---@private
---@return table<string, any>
function Console:_make_environment()
    ---@type table<string, any>
    local environment = setmetatable({}, {
        __index = _G
    })
    ---@type table<string, ConsoleFunction>
    local functions = {
        watch = function(name, fn)
            self:_watch(name, fn)
        end,
        unwatch = function(name)
            return self:_unwatch(name)
        end,
        watches = function()
            return table.copy(self._watch_names)
        end,
        pause = function()
            app.main_loop:pause()
        end,
        resume = function()
            app.main_loop:resume()
        end,
        frames = function(n)
            if not app.main_loop:is_paused() then
                app.main_loop:pause()
            end
            app.main_loop:step(n)
        end,
        screenshot = function(name)
            return self:_screenshot(name)
        end,
        log = function(enabled)
            self:_set_logging(enabled ~= false)
        end,
        run = function(chunk)
            self:_run(chunk)
        end,
        quit = function(exit_code)
            app:quit(exit_code)
            -- A quit is honored by the next update, and a paused loop runs none
            app.main_loop:resume()
        end
    }
    for name, fn in pairs(functions) do
        environment[name] = fn
    end
    return environment
end

---@private
---@param name string
---@param fn fun(): ...: any
function Console:_watch(name, fn)
    assert_type(name, "string")
    assert_type(fn, "function")
    assert(name ~= "" and not string.find(name, "[\t\n]"), "a watch's name is not empty and has no tab or line break")
    if not self._watches[name] then
        local names = table.copy(self._watch_names)
        table.insert(names, name)
        table.sort(names)
        self._watch_names = names
    end
    self._watches[name] = {
        fn = fn,
        value = nil,
        frame = 0,
        time = 0
    }
end

---@private
---@param name string
---@return boolean watched Whether there was such a watch
function Console:_unwatch(name)
    if not self._watches[name] then
        return false
    end
    self._watches[name] = nil
    ---@type string[]
    local names = {}
    for _, other in ipairs(self._watch_names) do
        if other ~= name then
            table.insert(names, other)
        end
    end
    self._watch_names = names
    self._overlay_stale = true
    return true
end

---@private
---@param name string A file name in the save directory
---@return string path Where the file is once the frame has been drawn
function Console:_screenshot(name)
    assert_type(name, "string")
    assert(app.root, "a screenshot needs a window")
    love.graphics.captureScreenshot(name)
    return love.filesystem.getSaveDirectory() .. "/" .. name
end

---@private
---@param text string A Lua chunk, run as a scenario over `driver` and `steps`
function Console:_run(text)
    assert_type(text, "string")
    local peer = assert(self._current, "run replies to the client whose chunk calls it")
    local runner = assert(app.scenario_runner, "run needs a scenario runner, the client's")
    assert(not runner:is_running(), "a scenario is running")
    local chunk, err = loadstring(text, "=peer")
    if not chunk then
        error(err, 0)
    end
    self._runs = self._runs + 1
    local id = self._runs
    peer.run = id
    ---@param driver ScenarioDriver
    ---@return any ...
    local function scenario(driver)
        debug.setfenv(chunk, setmetatable({
            driver = driver,
            steps = require("scenarios.lib.steps")
        }, {
            __index = _G
        }))
        return chunk()
    end
    ---@param result ScenarioResult
    ---@param ... any
    local function on_end(result, ...)
        if peer.run ~= id then
            return
        end
        peer.run = nil
        if result.ok then
            self:_queue(peer, "ok", _serialize(_pack(...), 1))
        else
            self:_queue(peer, "error", result.traceback or tostring(result.error))
        end
    end
    runner:start_function("peer", scenario, false, on_end)
end

---@private
---@param enabled boolean
function Console:_set_logging(enabled)
    local peer = assert(self._current, "log streams to the client whose chunk calls it")
    peer.logging = enabled
    self:_update_sink()
end

---@private
function Console:_update_sink()
    for _, peer in ipairs(self._peers) do
        if peer.logging and not peer.closed then
            Logger.set_sink(self._sink)
            return
        end
    end
    Logger.set_sink(nil)
end

---@private
---@param line string
function Console:_on_log_line(line)
    for _, peer in ipairs(self._peers) do
        if peer.logging then
            self:_queue(peer, "log", line)
        end
    end
end

---@private
function Console:_on_service()
    self:_accept()
    for _, peer in ipairs(self._peers) do
        if not peer.closed then
            self:_receive(peer)
        end
        if not peer.closed then
            self:_take_frames(peer)
        end
    end
    self:_evaluate_watches()
    ---@type ConsolePeer[]
    local open = {}
    for _, peer in ipairs(self._peers) do
        if not peer.closed then
            self:_flush(peer)
        end
        if not peer.closed then
            table.insert(open, peer)
        end
    end
    self._peers = open
end

---@private
function Console:_accept()
    local listener = assert(self._listener)
    while true do
        local stream = listener:accept()
        if not stream then
            return
        end
        stream:settimeout(0)
        ---@type ConsolePeer
        local peer = {
            socket = stream,
            input = "",
            kind = nil,
            length = 0,
            output = "",
            logging = false,
            closed = false,
            run = nil
        }
        table.insert(self._peers, peer)
        self:_send_watches(peer)
    end
end

---@private
---@param peer ConsolePeer
function Console:_send_watches(peer)
    for _, name in ipairs(self._watch_names) do
        local watch = self._watches[name]
        if watch and watch.value then
            self:_queue(peer, "watch", self:_watch_body(name, watch))
        end
    end
end

---@private
---@param name string
---@param watch ConsoleWatch
---@return string
function Console:_watch_body(name, watch)
    return string.format("%s\t%d\t%.3f\t%s", name, watch.frame, watch.time, watch.value)
end

---@private
---@param peer ConsolePeer
---@param reason string|nil Logged; `nil` for a client that closed by itself
function Console:_close(peer, reason)
    peer.closed = true
    peer.socket:close()
    if peer.logging then
        peer.logging = false
        self:_update_sink()
    end
    if reason then
        app:log("console: closed a client: " .. reason)
    end
end

---@private
---@param peer ConsolePeer
function Console:_receive(peer)
    local pieces = {
        peer.input
    }
    local received = #peer.input
    -- Bounded, so a client sending without end is read on in the next iterations
    while received < Console.MAX_HEADER_LENGTH + Console.MAX_BODY_LENGTH do
        local data, err, partial = peer.socket:receive(Console.RECEIVE_SIZE)
        local piece = data or partial or ""
        table.insert(pieces, piece)
        received = received + #piece
        if not data then
            if err ~= "timeout" then
                self:_close(peer, nil)
            end
            break
        end
    end
    peer.input = table.concat(pieces)
end

---@private
---@param peer ConsolePeer
function Console:_take_frames(peer)
    while not peer.closed and not peer.run do
        if not peer.kind then
            local newline = string.find(peer.input, "\n", 1, true)
            if not newline then
                if #peer.input > Console.MAX_HEADER_LENGTH then
                    self:_close(peer, "a header line too long")
                end
                return
            end
            local line = string.sub(peer.input, 1, newline - 1)
            peer.input = string.sub(peer.input, newline + 1)
            local kind, length = string.match(line, "^(%l+) (%d+)$")
            if kind ~= "eval" then
                self:_close(peer, string.format("a malformed header %q", line))
                return
            end
            local body_length = assert(tonumber(length))
            if body_length > Console.MAX_BODY_LENGTH then
                self:_close(peer, string.format("a body of %d bytes, over the limit of %d", body_length, Console.MAX_BODY_LENGTH))
                return
            end
            peer.kind, peer.length = kind, body_length
        end
        if #peer.input < peer.length then
            return
        end
        local body = string.sub(peer.input, 1, peer.length)
        peer.input = string.sub(peer.input, peer.length + 1)
        peer.kind = nil
        self:_evaluate(peer, body)
    end
end

---@private
---@param peer ConsolePeer
---@param text string A Lua chunk
function Console:_evaluate(peer, text)
    local chunk, err = loadstring(text, "=console")
    if not chunk then
        self:_queue(peer, "error", tostring(err))
        return
    end
    debug.setfenv(chunk, self._environment)
    self._current = peer
    local results = _pack(xpcall(chunk, debug.traceback))
    self._current = nil
    if not results[1] then
        -- A run the chunk started before it raised replies nothing: this error is the eval's one reply
        peer.run = nil
        self:_queue(peer, "error", _serialize_value(results[2]))
    elseif not peer.run then
        self:_queue(peer, "ok", _serialize(results, 2))
    end
end

---@private
function Console:_evaluate_watches()
    for _, name in ipairs(self._watch_names) do
        local watch = self._watches[name]
        if watch then
            local results = _pack(pcall(watch.fn))
            local value = results[1] and _serialize(results, 2) or _serialize_value(results[2])
            if value ~= watch.value then
                watch.value, watch.frame, watch.time = value, app.main_loop:get_frame(), app:get_time()
                self._overlay_stale = true
                local body = self:_watch_body(name, watch)
                for _, peer in ipairs(self._peers) do
                    self:_queue(peer, "watch", body)
                end
            end
        end
    end
    if self._overlay_stale then
        self._overlay_stale = false
        self:_refresh_overlay()
    end
end

---@private
function Console:_refresh_overlay()
    local overlay = self._overlay
    if not overlay then
        return
    end
    ---@type string[]
    local lines = {}
    for _, name in ipairs(self._watch_names) do
        local watch = self._watches[name]
        if watch then
            table.insert(lines, name .. ": " .. (watch.value or ""))
        end
    end
    overlay:set_lines(lines)
end

---@private
---@param peer ConsolePeer
---@param kind string
---@param body string
function Console:_queue(peer, kind, body)
    if peer.closed then
        return
    end
    peer.output = peer.output .. string.format("%s %d\n", kind, #body) .. body
    if #peer.output > Console.SEND_BUFFER_LIMIT then
        self:_close(peer, string.format("over %d bytes it does not read", Console.SEND_BUFFER_LIMIT))
    end
end

---@private
---@param peer ConsolePeer
function Console:_flush(peer)
    if peer.output == "" then
        return
    end
    local last, err, partial_last = peer.socket:send(peer.output)
    peer.output = string.sub(peer.output, (last or partial_last or 0) + 1)
    if not last and err ~= "timeout" then
        self:_close(peer, nil)
    end
end

return Console

---The Local Lua Debugger of VS Code (`ismoh-games.second-local-lua-debugger-vscode`).
---A `lua-local` launch configuration sets `LOCAL_LUA_DEBUGGER_VSCODE` in the
---program's environment and puts the debugger's module on `LUA_PATH`; without
---the variable every function here is a no-op, and the program runs as it
---does from the shell.
---@class debugger
local debugger = {}

---The extension's module, the part of it used here
---@class lldebugger
---@field start fun(break_immediately: boolean|nil) Hooks the Lua state; pauses on the first line when told to (by default when the extension is attached, which then continues by itself)
---@field requestBreak fun() Pauses on the next line executed

---@type lldebugger|nil Loaded by `start`, while attached
local lldebugger = nil

---@return boolean
function debugger.is_attached()
    return os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
end

---Hooks the debugger into the Lua state when it is attached; the entry point
---calls it before anything else runs, with the require path in place, and a
---second call does nothing.
function debugger.start()
    if debugger.is_attached() and not lldebugger then
        -- lua-lifetime replaces the coroutine functions, and the debugger
        -- takes them as it finds them when it loads, to hook its own over
        -- them at the start: loaded first, lifetime's stay under the hook
        require("lifetime")
        ---@type lldebugger
        local module = require("lldebugger")
        lldebugger = module
        module.start()
    end
end

---Pauses the debugger, when attached, on the next line executed, with the
---stack as it is: an error handler calls it so that an uncaught runtime error
---(an index of `nil`, a bad argument to a LÖVE function) can be inspected in
---the frame that raised it. The extension pauses on its own only at an error
---nothing catches, and under LÖVE everything runs inside the main loop's
---`xpcall`, so a handler asks every time.
function debugger.pause()
    if lldebugger then
        lldebugger.requestBreak()
    end
end

return debugger

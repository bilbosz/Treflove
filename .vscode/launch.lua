-- .vscode/launch.lua: what the entry points run under the debugger of the
-- "Local Lua Debugger" extension (tomblind.local-lua-debugger-vscode),
-- which the "Debug ..." configurations of .vscode/launch.json start
-- (docs/development.md, "Editor Support"). conf.lua (the first chunk LÖVE
-- runs) and tests/run.lua load it before anything else, and only when the
-- extension started the process (LOCAL_LUA_DEBUGGER_VSCODE=1); nothing
-- else reads it, and it is not part of the app.
--
-- It does two things.
--
-- 1. It starts the debugger and puts the host's functions back. Once
--    started, the debugger replaces `error`, `assert`, `debug.traceback`,
--    `coroutine.resume` and `coroutine.wrap` with functions that stop at
--    every raise, caught or not, and raise the error value again as a
--    string. The lifetime runtime asks the host how `coroutine.wrap`
--    re-raises a number when it loads (lib/lua-lifetime/lifetime/init.lua,
--    `WRAP_PREFIXES_NUMBERS`) and binds `coroutine.resume` and
--    `coroutine.wrap` for its unwinding on the error path, and the code
--    raises on purpose under `pcall` (the `_try_` constructors of
--    utils/media.tlt), so under the replacements the program would stop at
--    every caught raise, or not run at all. This script starts the
--    debugger first, puts the host's functions back, and only then does
--    the program load, so it observes what it observes without the
--    debugger. `coroutine.create` stays the debugger's: it creates through
--    the host's and registers the thread, which the debugger needs before
--    it can stop inside it; the runtime binds it when it loads. With
--    "breakInCoroutines" on, the debugger's `coroutine.create` also wraps
--    the body in a protected call that turns an error into a string, so
--    that option is refused. What is lost is the debugger's stop on an
--    uncaught error: LÖVE's error handler (app/app.tlt) or the test runner
--    reports it, with its traceback, as it does without the debugger.
--
-- 2. It makes breakpoints set in .tlt files stop there. A breakpoint is
--    matched by the running chunk's name, and the modules run from build/
--    (build/utils/tree.lua for utils/tree.tlt). The build keeps every
--    statement on its source line (docs/development.md, "The Build"), so
--    the searcher below, inserted after `package.preload`, loads each
--    built module under the name of the file it was built from: a .tlt
--    module under its .tlt, the lifetime runtime (copied to
--    build/lifetime/init.lua) under lib/lua-lifetime/lifetime/init.lua.
--    The stack and the tracebacks then name the sources too. The networking
--    threads (networking/detail/) are Lua states of their own, started from
--    build/, and are not debugged.
if os.getenv("LOCAL_LUA_DEBUGGER_BREAK_IN_COROUTINES") == "1" then
    io.stderr:write("launch.lua: set \"breakInCoroutines\" to false in .vscode/launch.json\n")
    os.exit(2)
end

local host_error, host_assert, host_traceback = error, assert, debug.traceback
local host_resume, host_wrap = coroutine.resume, coroutine.wrap
-- Stops here until the extension has sent the breakpoints.
require("lldebugger").start()
rawset(_G, "error", host_error)
rawset(_G, "assert", host_assert)
rawset(debug, "traceback", host_traceback)
rawset(coroutine, "resume", host_resume)
rawset(coroutine, "wrap", host_wrap)

-- Under LÖVE the files are read through love.filesystem (the source
-- directory is mounted); under plain LuaJIT from the current directory,
-- the repository root, as tests/run.lua requires.
local function read_file(path)
    if love and love.filesystem then
        return (love.filesystem.read(path))
    end
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local contents = file:read("*a")
    file:close()
    return contents
end

-- The source a built module was built from, by its path relative to
-- build/ without the extension ("utils/tree", "lifetime/init").
local SOURCES = {
    "%s.tlt",
    "lib/lua-lifetime/%s.lua"
}
local function source_of(built)
    for _, pattern in ipairs(SOURCES) do
        local path = pattern:format(built)
        if read_file(path) then
            return path
        end
    end
    return nil
end

local function searcher(name)
    local built = name:gsub("%.", "/")
    for _, candidate in ipairs({
        built,
        built .. "/init"
    }) do
        local code = read_file("build/" .. candidate .. ".lua")
        if code then
            local source = source_of(candidate)
            if not source then
                -- Built from nothing this script knows: the next searcher
                -- loads it under its own name.
                return nil
            end
            return assert(loadstring(code, "@" .. source))
        end
    end
    return nil
end

-- After package.preload (the stubs of tests/run.lua), before the file
-- searchers of Lua and LÖVE.
---@diagnostic disable-next-line: deprecated
table.insert(package.loaders or package.searchers, 2, searcher)

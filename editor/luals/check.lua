-- editor/luals/check.lua: runs the rewrite of editor/luals/plugin.lua over
-- `.tlt` files and checks that each result is syntactically valid Lua, as
-- the language server will parse it. Prints one line when every file
-- passes; exit status 1 when any file fails. ./test-code.sh runs it over
-- every `.tlt` file of the repository.
--
--   luajit editor/luals/check.lua FILE...           check
--   luajit editor/luals/check.lua --print FILE...   print each rewrite
--
-- Runs under LuaJIT and Lua 5.1 (the rewrite of a `.tlt` file is Lua
-- 5.1), and under the language server's own Lua 5.4, which is the one the
-- plugin runs under in the editor. lua-lifetime's editor/luals/check.lua
-- is the same script for `.lt` files.
local here = (arg[0]:match("^(.*)[/\\]")) or "."

local function load_with_env(path, env)
    if setfenv then
        local f = assert(loadfile(path))
        setfenv(f, env)
        return f
    end
    return assert(loadfile(path, "t", env))
end

local compile = loadstring or load

-- The server's string-merger.mergeDiff: diffs by ascending start, each
-- replacing text[start..finish] (finish = start - 1 inserts).
local function merge(text, diffs)
    table.sort(diffs, function(a, b)
        return a.start < b.start
    end)
    local buf, cur = {}, 1
    for _, d in ipairs(diffs) do
        buf[#buf + 1] = text:sub(cur, d.start - 1)
        buf[#buf + 1] = d.text
        cur = d.finish + 1
    end
    buf[#buf + 1] = text:sub(cur)
    return table.concat(buf)
end

local env = setmetatable({}, {
    __index = _G
})
load_with_env(here .. "/plugin.lua", env)()
local OnSetText = assert(env.OnSetText, "plugin.lua did not define OnSetText")

local print_result = false
local failed = 0
local checked = 0
for i = 1, #arg do
    local path = arg[i]
    if path == "--print" then
        print_result = true
    else
        local f = assert(io.open(path, "rb"))
        local text = f:read("*a")
        f:close()
        local diffs = OnSetText("file:///" .. path, text)
        local result = diffs and merge(text, diffs) or text
        if print_result then
            io.write("== ", path, "\n", result, "\n")
        end
        checked = checked + 1
        local chunk, err = compile(result, "=" .. path)
        if not chunk then
            failed = failed + 1
            io.stderr:write(path, ": rewrite does not compile: ", err, "\n")
        end
    end
end
if failed > 0 then
    io.stderr:write(("editor/luals/check.lua: %d of %d files failed\n"):format(failed, checked))
    os.exit(1)
end
print(("editor/luals/check.lua: %d files rewritten and compiled"):format(checked))

-- Under the debugger of VS Code's "Local Lua Debugger" extension
-- (.vscode/launch.json): start it and load every module under its source's
-- name, so breakpoints in .tlt files stop there (.vscode/launch.lua). Here,
-- in the first chunk LÖVE runs, so that app/arg-parser below is covered too.
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    love.filesystem.load(".vscode/launch.lua")()
end

-- The modules are built into build/ (./build-code.sh); look there first.
love.filesystem.setRequirePath("build/?.lua;build/?/init.lua;?.lua;?/init.lua")

local arg_parser = require("app.arg-parser")

-- LÖVE's configuration, kept in the global `config` (typed `LoveConfig` in
-- app/app.d.tl for the Teal modules).
function love.conf(t)
    local params = arg_parser.parse(arg)

    -- "OS X", "Windows", "Linux", "Android" or "iOS"
    local os = love._os
    if os == "Windows" then
        t.console = true
    end

    if not params then
        t.window = nil
    elseif params.app_type == "server" then
        t.console = true
        if os == "Windows" then
            t.window.title = "Treflove - Server"
            t.window.icon = "icon.png"
        else
            t.window = nil
        end
    elseif params.app_type == "client" then
        t.window.title = "Treflove"
        t.window.icon = "icon.png"
        t.window.resizable = true
        t.window.fullscreen = false
        t.window.display = 1
    else
        assert_unreachable()
    end

    if t.window then
        t.window.width, t.window.height = 800, 600
        t.window.minwidth, t.window.minheight = 600, 600
    end

    config = t
end

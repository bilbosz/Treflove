love.filesystem.load("utils/loader.lua")()
if debug then
    Loader.LoadFile("utils/dump.lua")
end
Loader.LoadFile("utils/table.lua")
Loader.LoadFile("utils/class.lua")
Loader.LoadFile("app/arg-parser.lua")

local parser = ArgParser()
params = parser:Parse(arg)

function love.conf(t)
    if not params then
        t.window = nil
    elseif params.appType == "server" then
        t.window.title = "Treflove - Server"
        t.window.icon = "icon.png"
        if jit.os ~= "Windows" then
            t.window = nil
        end
        t.console = true
    elseif params.appType == "client" then
        t.window.title = "Treflove"
        t.window.icon = "icon.png"
        t.window.display = 2
    else
        assert(false)
    end
    config = t
end

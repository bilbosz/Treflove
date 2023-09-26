love.filesystem.load("utils/loader.lua")()
Loader.LoadFile("utils/utils.lua")
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
        if love._os ~= "Windows" then
            t.window = nil
        end
        t.console = true
    elseif params.appType == "client" then
        t.window.title = "Treflove"
        t.window.icon = "icon.png"
        t.window.resizable = true
        t.window.fullscreen = false
        t.window.display = 2
    else
        assert(false)
    end
    if t.window then
        t.window.width, t.window.height = 800, 600
        t.window.minwidth, t.window.minheight = 600, 600
    end
    config = t
end

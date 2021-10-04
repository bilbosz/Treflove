love.filesystem.load("utils/loader.lua")()
if debug then
    Loader:LoadFile("utils/dump.lua")
end
Loader:LoadFile("utils/table.lua")
Loader:LoadFile("utils/class.lua")
Loader:LoadClass("app/arg-parser.lua")

params = ArgParser():Parse(arg)

function love.conf(t)
    if not params then
        t.window = nil
    elseif params.appType == "server" then
        t.window.title = "Treflove - Server"
        t.window.icon = "icon.png"
        -- t.window.display = 2
        -- t.window = nil
        -- t.window.width = 1000
        -- t.window.height = 500
        -- t.window.width = 1920
        -- t.window.height = 1080
        -- t.window.fullscreen = true
        t.console = true
    elseif params.appType == "client" then
        t.window.title = "Treflove"
        t.window.icon = "icon.png"
    else
        assert(false)
    end
    config = t
end

love.filesystem.load("utils/loader.lua")()
if debug then
    dump = Loader:Load("utils/dump.lua")
end
Loader:Load("utils/table.lua")
Loader:Load("utils/class.lua")
Loader:Load("app/arg-parser.lua")

params = ArgParser():Parse(arg)

function love.conf(t)
    if not params then
        t.window = nil
    elseif params.appType == "server" then
        t.window.title = "Treflun - Server"
        t.window.icon = "icon.png"
        -- t.window = nil
        t.window.width = 1000
        t.window.height = 500
        -- t.window.width = 1920
        -- t.window.height = 1080
        -- t.window.fullscreen = true
        t.console = true
    elseif params.appType == "client" then
        t.window.title = "Treflun"
        t.window.icon = "icon.png"
    else
        assert(false)
    end
    config = t
end

local ArgParser = require("app.arg-parser")

function love.conf(t)
    local params = ArgParser.parse(arg)
    if not params then
        t.window = nil
    elseif params.app_type == "server" then
        t.window.title = "Treflove - Server"
        t.window.icon = "icon.png"
        if love._os ~= "Windows" then
            t.window = nil
        end
        t.console = true
    elseif params.app_type == "client" then
        t.window.title = "Treflove"
        t.window.icon = "icon.png"
        t.window.resizable = true
        t.window.fullscreen = false
        t.window.display = 2
    else
        assert_unreachable()
    end
    if t.window then
        t.window.width, t.window.height = 800, 600
        t.window.minwidth, t.window.minheight = 600, 600
    end
    config = t
end

local arg_parser = require("app.arg-parser")

---@class love.ConfigTable
---@field console boolean
---@field window love.WindowConfig|nil

---@class love.WindowConfig
---@field title string
---@field icon string
---@field resizable boolean
---@field fullscreen boolean
---@field display number
---@field width number
---@field height number
---@field minwidth number
---@field minheight number

---@param t love.ConfigTable
function love.conf(t)
    local params = arg_parser.parse(arg)

    ---@type "OS X"|"Windows"|"Linux"|"Android"|"iOS"
    ---@diagnostic disable-next-line: undefined-field
    local os = love._os
    if os == "Windows" then
        t.console = true
    end

    if not params then
        t.window = nil
    elseif params.app_type == "server" then
        t.console = true
        if true or os == "Windows" then
            t.window.title = "Treflove - Server"
            t.window.icon = "icon.png"
        else
            t.window = nil
        end
    elseif params.app_type == "client" then
        t.window.title = "Treflove"
        t.window.icon = "icon.png"
        t.window.resizable = true
        t.window.fullscreen = true
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

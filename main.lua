love.filesystem.load("utils/loader.lua")()
if debug then
    Loader:LoadFile("utils/dump.lua")
end
Loader:LoadFile("utils/utils.lua")
Loader:LoadFile("utils/table.lua")
Loader:LoadFile("utils/class.lua")
Loader:LoadClass("app/arg-parser.lua")
Loader:LoadModule("controls")
Loader:LoadModule("game")
Loader:LoadModule("login")
Loader:LoadModule("screens")
Loader:LoadModule("networking")

local params = ArgParser():Parse(arg)

if not params then
    print("Usage:\n    treflun <app_type> <address> <port>")
    love.event.quit(0)
    return
end

if params.appType == "client" then
    Loader:LoadClass("app/client.lua")
    Client(params)
elseif params.appType == "server" then
    Loader:LoadClass("app/server.lua")
    Server(params)
else
    assert(false)
end

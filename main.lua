love.filesystem.load("utils/loader.lua")()
if debug then
    Loader:LoadFile("utils/dump.lua")
end
Loader:LoadFile("utils/utils.lua")
Loader:LoadFile("utils/table.lua")
Loader:LoadFile("utils/class.lua")
Loader:LoadClass("app/arg-parser.lua")
Loader:LoadModule("controls")
Loader:LoadModule("login")
Loader:LoadModule("game")

local params = ArgParser():Parse(arg)

if not params then
    print("Usage:\n    treflun <app_type> <address> <port>")
    love.event.quit(0)
    return
end

if params.appType == "client" then
    Loader:LoadClass("app/client/client.lua")
    app = Client(params)
elseif params.appType == "server" then
    Loader:LoadClass("app/server/server.lua")
    app = Server(params)
else
    assert(false)
end

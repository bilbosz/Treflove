love.filesystem.load("utils/loader.lua")()
if debug then
    dump = Loader:Load("utils/dump.lua")
end
Loader:Load("utils/utils.lua")
Loader:Load("utils/table.lua")
Loader:Load("utils/class.lua")
Loader:Load("app/arg-parser.lua")
Loader:Load("app/app.lua")

local params = ArgParser():Parse(arg)

if not params then
    print("Usage:\n    treflun <app_type> <address> <port>")
    love.event.quit(0)
    return
end

if params.appType == "client" then
    Loader:Load("app/client.lua")
    app = Client(params)
elseif params.appType == "server" then
    Loader:Load("app/server.lua")
    app = Server(params)
else
    assert(false)
end
app:PostInit()
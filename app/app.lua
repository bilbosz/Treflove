params = ArgParser():Parse(arg)

if not params then
    print("Usage:\n    treflun <app_type> <address> <port>")
    love.event.quit(0)
    return
end

if params.appType == "client" then
    Client = Loader:Load("app/client.lua")
    App = Client
elseif params.appType == "server" then
    Server = Loader:Load("app/server.lua")
    App = Server
else
    assert(false)
end
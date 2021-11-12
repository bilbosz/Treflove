love.filesystem.load("utils/loader.lua")()
Loader.LoadModule(".")

local parser = ArgParser()
local params = parser:Parse(arg)

if not params then
    print("Usage:\n    treflun <app_type> <address> <port>")
    love.event.quit(0)
    return
end

if params.appType == "client" then
    Loader.LoadFile("app/client.lua")
    Client(params)
elseif params.appType == "server" then
    Loader.LoadFile("app/server.lua")
    Server(params)
else
    assert(false)
end

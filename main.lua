love.filesystem.load("utils/loader.lua")()
if debug then
    dump = Loader:Load("utils/dump.lua")
end
Loader:Load("utils/table.lua")
Loader:Load("utils/class.lua")
Loader:Load("app/arg-parser.lua")
Loader:Load("app/app.lua")
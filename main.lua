love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";lib/lua-lifetime/?.lua;lib/lua-lifetime/?/init.lua")
require("app.globals")

if arg[2] == "test" then
    require("tests.run")
end

local Consts = require("app.consts")
local Utils = require("utils.utils")

local arg_parser = require("app.arg-parser")

local params = arg_parser.parse(arg)
if not params then
    io.write(Consts.APP_USAGE_MESSAGE)
    love.event.quit(Consts.APP_SUCCESS_EXIT_CODE)
elseif params.app_type == "client" then
    xpcall(function()
        require("app.client")(params)
    end, Utils.error_handler("client-init"))
elseif params.app_type == "server" then
    require("app.server")(params)
else
    assert_unreachable()
end

love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";lib/lua-lifetime/?.lua;lib/lua-lifetime/?/init.lua")
require("app.debugger").start()
require("app.globals")

if arg[2] == "test" then
    require("tests.run")
end

local Consts = require("app.consts")
local Utils = require("utils.utils")

local arg_parser = require("app.arg-parser")
local ConsoleSession = require("utils.console-session")

local params = arg_parser.parse(arg)
if not params then
    io.write(Consts.APP_USAGE_MESSAGE)
    love.event.quit(arg[2] == "console" and ConsoleSession.EXIT_FAILURE or Consts.APP_SUCCESS_EXIT_CODE)
elseif params.app_type == "client" then
    xpcall(function()
        require("app.client")(params)
    end, Utils.error_handler("client-init"))
elseif params.app_type == "server" then
    require("app.server")(params)
elseif params.app_type == "console" then
    require("app.console-app")(params):install()
elseif params.app_type == "monitor" then
    require("app.monitor")(params)
else
    assert_unreachable()
end

require("app.globals")

local ArgParser = require("app.arg-parser")
local Consts = require("app.consts")
local Utils = require("utils.utils")

local params = ArgParser.parse(arg)
if not params then
    print(Consts.APP_USAGE_MESSAGE)
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

-- Prints the auth of a fixture player: the server-side hash of the client-side hash, each under its side's seed,
-- with the project's own hashing (utils/utils.lua), so the fixture's save.lua accepts the login
local login, password = arg[2], arg[3]
if not login or not password then
    io.stderr:write("usage: love <this directory> <login> <password>\n")
    love.event.quit(2)
    return
end
local root = love.filesystem.getSource():gsub("/%.claude/skills/scenario%-authoring/scripts/player%-auth$", "")
package.path = root .. "/?.lua;" .. root .. "/lib/lua-lifetime/?.lua;" .. root .. "/lib/lua-lifetime/?/init.lua;" .. package.path
require("app.globals")
local Utils = require("utils.utils")
app = { is_server = false }
local client_auth = Utils.hash(login .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. password)
app = { is_server = true }
local server_auth = Utils.hash(login .. string.char(0) .. Utils.generate_salt(32) .. string.char(0) .. client_auth)
print(server_auth)
io.stdout:flush()
love.event.quit(0)

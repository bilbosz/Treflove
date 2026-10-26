---@type string
local root = (string.match(arg[0], "^(.*)/[^/]*$") or ".") .. "/.."
package.path = string.format("%s/?.lua;%s/lib/lua-lifetime/?.lua;%s/lib/lua-lifetime/?/init.lua;", root, root, root) .. package.path
require("app.globals")

local ConsoleSession = require("utils.console-session")

local USAGE = [[
Usage:
    luajit tools/console.lua <port> [chunk] [options]
Sends the Lua chunk (stdin until its end without one, or for "-") to the
console port and prints its results; a failure goes to stderr.
Options, anywhere among the arguments:
    --host <host>    the console's host, 127.0.0.1 by default
    --follow         after the reply, print every watch and log frame until the connection closes
    --watch <expr>   watch the expression under its own text and follow
Exit code: 0 for a result, 1 for an error, 2 for a usage or connection failure.
]]

---@param line string
---@param is_error boolean
local function output(line, is_error)
    (is_error and io.stderr or io.stdout):write(line, "\n")
end

---@param args string[]
---@return integer exit_code
local function run(args)
    local options = ConsoleSession.parse(args)
    if not options then
        io.stderr:write(USAGE)
        return ConsoleSession.EXIT_FAILURE
    end
    if not options.chunk and not options.watch then
        options.chunk = io.read("*a")
    end
    ---@type boolean, ConsoleSession|string
    local connected, session = pcall(function()
        return ConsoleSession(options.host or "127.0.0.1", options.port, options, output)
    end)
    if not connected or type(session) == "string" then
        output(tostring(session), true)
        return ConsoleSession.EXIT_FAILURE
    end
    session:start()
    while session:step(1) do
    end
    session:close()
    return session:get_exit_code()
end

io.stdout:setvbuf("line")
local exit_code = run(arg)
io.stdout:flush()
os.exit(exit_code)

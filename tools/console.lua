---@type string|nil
local module_name = ...
local is_main = module_name ~= "tools.console"

if is_main then
    ---@type string
    local root = (string.match(arg[0], "^(.*)/[^/]*$") or ".") .. "/.."
    package.path = string.format("%s/?.lua;%s/lib/lua-lifetime/?.lua;%s/lib/lua-lifetime/?/init.lua;", root, root, root) .. package.path
    require("app.globals")
end

local ConsoleClient = require("utils.console-client")

---@class console_cli
local console_cli = {}

console_cli.USAGE = [[
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

console_cli.EXIT_OK = 0
console_cli.EXIT_ERROR = 1
console_cli.EXIT_FAILURE = 2

---@class ConsoleCliOptions
---@field host string|nil
---@field port string
---@field chunk string|nil `nil`: read stdin until its end
---@field follow boolean

---@param expression string
---@return string chunk Watches the expression under its own text
function console_cli.watch_chunk(expression)
    return string.format("watch(%q, function()\nreturn %s\nend)", expression, expression)
end

---@param args string[] The script's arguments, from `arg[1]` on
---@return ConsoleCliOptions|nil options `nil` for a usage error
function console_cli.parse(args)
    ---@type string|nil, string|nil, boolean
    local host, watch, follow = nil, nil, false
    ---@type string[]
    local positional = {}
    local i = 1
    while args[i] do
        local argument, value = args[i], args[i + 1]
        if argument == "--follow" then
            if follow then
                return nil
            end
            follow = true
            i = i + 1
        elseif argument == "--host" then
            if host or not value then
                return nil
            end
            host = value
            i = i + 2
        elseif argument == "--watch" then
            if watch or not value then
                return nil
            end
            watch = value
            i = i + 2
        else
            table.insert(positional, argument)
            i = i + 1
        end
    end
    ---@type string|nil, string|nil
    local port, chunk = positional[1], positional[2]
    local number = tonumber(port)
    if not port or not string.match(port, "^%d+$") or not number or number < 1 or number > 65535 or positional[3] then
        return nil
    end
    if watch then
        if chunk then
            return nil
        end
        chunk = console_cli.watch_chunk(watch)
        follow = true
    elseif chunk == "-" then
        chunk = nil
    end
    return {
        host = host,
        port = port,
        chunk = chunk,
        follow = follow
    }
end

---@param args string[]
---@return integer exit_code
function console_cli.run(args)
    local options = console_cli.parse(args)
    if not options then
        io.stderr:write(console_cli.USAGE)
        return console_cli.EXIT_FAILURE
    end
    local chunk = options.chunk or io.read("*a")
    ---@type boolean, ConsoleClient|string
    local connected, client = pcall(function()
        return ConsoleClient(options.port, options.host)
    end)
    if not connected or type(client) == "string" then
        io.stderr:write(tostring(client), "\n")
        return console_cli.EXIT_FAILURE
    end
    if options.follow then
        io.stdout:setvbuf("line")
        client:set_frame_handler(function(_, body)
            io.stdout:write(body, "\n")
        end)
    end
    ---@type boolean, boolean|string, string|nil
    local answered, ok, body = pcall(client.request, client, chunk)
    if not answered or not body then
        io.stderr:write(tostring(ok), "\n")
        client:close()
        return console_cli.EXIT_FAILURE
    end
    if not ok then
        io.stderr:write(body, "\n")
        client:close()
        return console_cli.EXIT_ERROR
    end
    if body ~= "" then
        io.stdout:write(body, "\n")
    end
    if options.follow then
        io.stdout:flush()
        while client:poll(1) do
        end
    end
    client:close()
    return console_cli.EXIT_OK
end

if is_main then
    local exit_code = console_cli.run(arg)
    io.stdout:flush()
    os.exit(exit_code)
end

return console_cli

require("utils.class")

---@class arg_parser Example usage: `love . server 0.0.0.0 8080`, `love . client 192.0.0.1 8080 --scenario join-game`, `love . console 127.0.0.1 9090 "return 1"` or `love . monitor 127.0.0.1 client:9090,server:9091`
local arg_parser = {}

---@alias AppType "server"|"client"|"console"|"monitor"

---@param str string
---@return AppType|nil Input string or `nil` when provided string was wrong
local function _parse_app_type(str)
    if str == "server" or str == "client" or str == "console" or str == "monitor" then
        return str
    end
    return nil
end

---@param str string
---@return string|nil Input string or `nil` when provided string was wrong
local function _parse_address(str)
    if str == "localhost" then
        return str
    else
        local pattern = "(%d+)%.(%d+)%.(%d+)%.(%d+)"
        local findings = {
            string.find(str, pattern)
        }
        if #findings ~= 6 then
            return nil
        end
        for i = 3, 6 do
            local v = findings[i]
            local num = tonumber(v)
            if not num or num < 0 or num > 255 then
                return nil
            end
        end
        return str
    end
end

---@param str string
---@return string|nil Input string or `nil` when provided string was wrong
local function _parse_port(str)
    local num = tonumber(str)
    return num and num >= 1024 and num <= 65535 and str or nil
end

---@param str string
---@return string|nil Input string or `nil` when provided string was wrong
local function _parse_name(str)
    return str:find("^[%w_%-]+$") and str or nil
end

---@param str string
---@return string|nil Input string or `nil` when it is not a relative path of `[%w_%-.]+` components without `..`
local function _parse_relative_path(str)
    for component in (str .. "/"):gmatch("(.-)/") do
        if not component:find("^[%w_%-%.]+$") or component == ".." then
            return nil
        end
    end
    return str
end

---@param str string
---@return table<string, string>|nil ports The port of every name, `nil` for a malformed entry or a repeated name
local function _parse_named_ports(str)
    ---@type table<string, string>
    local ports = {}
    for entry in (str .. ","):gmatch("(.-),") do
        local name, port = entry:match("^([^:]*):(.*)$")
        if not name or not _parse_name(name) or not _parse_port(port) or ports[name] then
            return nil
        end
        ports[name] = port
    end
    return ports
end

---@param str string
---@return string|nil Input string or `nil` when it is not a comma-separated list of `<name>:<port>` with distinct names
local function _parse_peers(str)
    return _parse_named_ports(str) and str or nil
end

---@param str string
---@return string|nil Input string or `nil` when it is empty
local function _parse_expression(str)
    return str ~= "" and str or nil
end

---@alias ArgParserOptionField "scenario"|"console"|"server_console"|"identity"|"fixture"|"headless"|"peers"|"follow"|"watch"

---@class ArgParserOption
---@field field ArgParserOptionField
---@field parse (fun(str: string): string|nil)|nil The value's parser; `nil` for a flag, which takes no value
---@field sides table<AppType, true> The app types that accept the option

---@type table<string, ArgParserOption>
local OPTIONS = {
    ["--scenario"] = {
        field = "scenario",
        parse = _parse_name,
        sides = {
            client = true
        }
    },
    ["--console"] = {
        field = "console",
        parse = _parse_port,
        sides = {
            client = true,
            server = true,
            monitor = true
        }
    },
    ["--server-console"] = {
        field = "server_console",
        parse = _parse_port,
        sides = {
            client = true
        }
    },
    ["--identity"] = {
        field = "identity",
        parse = _parse_name,
        sides = {
            client = true,
            server = true
        }
    },
    ["--fixture"] = {
        field = "fixture",
        parse = _parse_relative_path,
        sides = {
            server = true
        }
    },
    ["--headless"] = {
        field = "headless",
        sides = {
            client = true,
            server = true,
            monitor = true
        }
    },
    ["--peers"] = {
        field = "peers",
        parse = _parse_peers,
        sides = {
            client = true
        }
    },
    ["--follow"] = {
        field = "follow",
        sides = {
            console = true
        }
    },
    ["--watch"] = {
        field = "watch",
        parse = _parse_expression,
        sides = {
            console = true
        }
    }
}

---@class ArgParserResult
---@field public app_type AppType
---@field public address string The host of the targets for the monitor
---@field public port string|nil Port number as string (range: 1024-65535); `nil` for the monitor
---@field public scenario string|nil Client only: the name of the file under `scenarios/` run at start
---@field public console string|nil The console port on 127.0.0.1, as string (range: 1024-65535)
---@field public server_console string|nil Client only: the server's console port, for the scenario driver
---@field public identity string|nil The LÖVE save directory identity
---@field public fixture string|nil Server only: a directory of the source tree that seeds the server root at load
---@field public headless boolean Fixed frame delta, no sleep, no vsync
---@field public peers table<string, string>|nil Client only: the console port of every peer client a scenario drives, by the peer's name
---@field public chunk string|nil Console only: the Lua chunk to evaluate; `nil` to read it from stdin, or for `--watch`
---@field public follow boolean Console only: after the reply, print every watch and log frame until the connection closes
---@field public watch string|nil Console only: an expression to watch under its own text, following
---@field public targets table<string, string>|nil Monitor only: the console port of every target by its name

---@param args string[]
---@param first integer The index of the first option
---@param app_type AppType
---@return table<ArgParserOptionField, string>|nil values The value of every option given with one, `nil` for an unknown, repeated or misplaced option or a missing or wrong value
---@return table<ArgParserOptionField, boolean> flags `true` for every flag given
---@return string[] positional The arguments that are neither an option nor its value, in order
local function _parse_options(args, first, app_type)
    ---@type table<ArgParserOptionField, string>
    local values = {}
    ---@type table<ArgParserOptionField, boolean>
    local flags = {}
    ---@type string[]
    local positional = {}
    local i = first
    while i <= #args do
        local argument = args[i]
        local option = OPTIONS[argument]
        if not argument:find("^%-%-") then
            table.insert(positional, argument)
            i = i + 1
        elseif not option or values[option.field] or flags[option.field] or not option.sides[app_type] then
            return nil, flags, positional
        elseif option.parse then
            local str = args[i + 1]
            local value = str and not str:find("^%-%-") and option.parse(str)
            if not value then
                return nil, flags, positional
            end
            values[option.field] = value
            i = i + 2
        else
            flags[option.field] = true
            i = i + 1
        end
    end
    return values, flags, positional
end

---@param args string[] Program argument list
---@return ArgParserResult|nil
function arg_parser.parse(args)
    if #args < 4 then
        return nil
    end
    local app_type, address = _parse_app_type(args[2]), _parse_address(args[3])
    if not app_type or not address then
        return nil
    end
    ---@type string|nil, table<string, string>|nil
    local port, targets
    if app_type == "monitor" then
        targets = _parse_named_ports(args[4])
        if not targets then
            return nil
        end
    else
        port = _parse_port(args[4])
        if not port then
            return nil
        end
    end
    local values, flags, positional = _parse_options(args, 5, app_type)
    if not values then
        return nil
    end
    ---@type string|nil
    local chunk = positional[1]
    if chunk and (app_type ~= "console" or positional[2] or values.watch) then
        return nil
    end
    return {
        app_type = app_type,
        address = address,
        port = port,
        scenario = values.scenario,
        console = values.console,
        server_console = values.server_console,
        identity = values.identity,
        fixture = values.fixture,
        headless = flags.headless == true,
        peers = values.peers and assert(_parse_named_ports(values.peers)),
        chunk = chunk ~= "-" and chunk or nil,
        follow = flags.follow == true,
        watch = values.watch,
        targets = targets
    }
end

return arg_parser

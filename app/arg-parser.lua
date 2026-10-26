require("utils.class")

---@class arg_parser Example usage: `love . server 0.0.0.0 8080` or `love . client 192.0.0.1 8080 --scenario join-game`
local arg_parser = {}

---@alias AppType "server"|"client"

---@param str string
---@return AppType|nil Input string or `nil` when provided string was wrong
local function _parse_app_type(str)
    return str == "server" and str or str == "client" and str or nil
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

---@alias ArgParserOptionField "scenario"|"console"|"server_console"|"identity"|"fixture"|"headless"

---@class ArgParserOption
---@field field ArgParserOptionField
---@field parse (fun(str: string): string|nil)|nil The value's parser; `nil` for a flag, which takes no value
---@field side AppType|nil The only app type that accepts the option; `nil` for both

---@type table<string, ArgParserOption>
local OPTIONS = {
    ["--scenario"] = {
        field = "scenario",
        parse = _parse_name,
        side = "client"
    },
    ["--console"] = {
        field = "console",
        parse = _parse_port
    },
    ["--server-console"] = {
        field = "server_console",
        parse = _parse_port,
        side = "client"
    },
    ["--identity"] = {
        field = "identity",
        parse = _parse_name
    },
    ["--fixture"] = {
        field = "fixture",
        parse = _parse_relative_path,
        side = "server"
    },
    ["--headless"] = {
        field = "headless"
    }
}

---@class ArgParserResult
---@field public app_type AppType
---@field public address string
---@field public port string Port number as string (range: 1024-65535)
---@field public scenario string|nil Client only: the name of the file under `scenarios/` run at start
---@field public console string|nil The console port on 127.0.0.1, as string (range: 1024-65535)
---@field public server_console string|nil Client only: the server's console port, for the scenario driver
---@field public identity string|nil The LÖVE save directory identity
---@field public fixture string|nil Server only: a directory of the source tree that seeds the server root at load
---@field public headless boolean Fixed frame delta, no sleep, no vsync

---@param args string[]
---@param first integer The index of the first option
---@param app_type AppType
---@return table<ArgParserOptionField, string>|nil values The value of every option given with one, `nil` for an unknown, repeated or misplaced option or a missing or wrong value
---@return table<ArgParserOptionField, boolean> flags `true` for every flag given
local function _parse_options(args, first, app_type)
    ---@type table<ArgParserOptionField, string>
    local values = {}
    ---@type table<ArgParserOptionField, boolean>
    local flags = {}
    local i = first
    while i <= #args do
        local option = OPTIONS[args[i]]
        if not option or values[option.field] or flags[option.field] or (option.side and option.side ~= app_type) then
            return nil, flags
        end
        if option.parse then
            local str = args[i + 1]
            local value = str and not str:find("^%-%-") and option.parse(str)
            if not value then
                return nil, flags
            end
            values[option.field] = value
            i = i + 2
        else
            flags[option.field] = true
            i = i + 1
        end
    end
    return values, flags
end

---@param args string[] Program argument list
---@return ArgParserResult|nil
function arg_parser.parse(args)
    if #args < 4 then
        return nil
    end
    local app_type, address, port = _parse_app_type(args[2]), _parse_address(args[3]), _parse_port(args[4])
    if not app_type or not address or not port then
        return nil
    end
    local values, flags = _parse_options(args, 5, app_type)
    if not values then
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
        headless = flags.headless == true
    }
end

return arg_parser

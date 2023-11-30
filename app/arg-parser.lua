require("utils.class")

---@class ArgParser Example usage: `love . server 0.0.0.0 8080` or `love . client 192.0.0.1 8080`
local ArgParser = class("ArgParser")

---@param str string
---@return string|nil Input string or `nil` when provided string was wrong
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
    return num and num >= 1024 and num <= 65535 and str
end

---@class ArgParserResult
---@field public app_type string
---@field public address string
---@field public port string

---@param args string[] Program argument list
---@return ArgParserResult|nil
function ArgParser.parse(args)
    if #args < 4 then
        return nil
    else
        local app_type, address, port = _parse_app_type(args[2]), _parse_address(args[3]), _parse_port(args[4])
        if not app_type or not address or not port then
            return nil
        end
        return {
            app_type = app_type,
            address = address,
            port = port
        }
    end
end

return ArgParser()

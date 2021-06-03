--[[
Example:
love . server 0.0.0.0 8080
love . client 192.0.0.1 8080
]]
ArgParser = class("ArgParser")

local function parseAppType(str)
    return str == "server" and str or str == "client" and str or false
end

local function parseAddress(str)
    if str == "localhost" then
        return str
    else
        local pattern = "(%d+)%.(%d+)%.(%d+)%.(%d+)"
        local findings = {string.find(str, pattern)}
        if #findings ~= 6 then
            return false
        end
        for i = 3, 6 do
            local v = findings[i]
            local num = tonumber(v)
            if not num or num < 0 or num > 255 then
                return false
            end
        end
        return str
    end
end

local function parsePort(str)
    local num = tonumber(str)
    return num and num >= 1024 and num <= 65535 and str
end

function ArgParser:Parse(args)
    if #args ~= 4 then
        return nil
    else
        local appType, address, port = parseAppType(args[2]), parseAddress(args[3]), parsePort(args[4])
        if not appType or not address or not port then
            return nil
        end
        return {
            appType = appType,
            address = address,
            port = port
        }
    end
end

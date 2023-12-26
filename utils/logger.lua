local Consts = require("app.consts")
local Model = require("data.model")
local Utils = require("utils.utils")

---@class Logger: Model
local Logger = class("Logger", Model)

local function _is_enabled(name)
    local n = #name
    for _, pattern in ipairs(Consts.LOGGER_NAME_BLACKLIST) do
        local start, stop = string.find(name, pattern)
        if start == 1 and stop == n then
            return false
        end
    end
    return true
end

local function _log_implementation(self, format, level, ...)
    if not self._is_enabled then
        return
    end
    local sep = self.separator
    local time_diff = Utils.get_time() - self.start_time
    local result = string.format("%8.3f%s%21s", time_diff, sep, self.name)
    if debug then
        local info = debug.getinfo(level, "Sl")
        local location = string.format("%s:%i", info.short_src, info.currentline)
        result = result .. string.format("%s%44s", sep, location)
    end
    result = result .. string.format("%s>%s" .. format, sep, sep, ...)
    print(result)
end

function Logger:init(data, name)
    assert_type(name, "string")
    Model.init(self, data)
    self.name = name
    self.data.start_time = self.data.start_time or Utils.get_time()
    self.start_time = self.data.start_time
    self.separator = " "
    self._is_enabled = _is_enabled(name)
end

function Logger:set_name(name)
    assert_type(name, "string")
    self.name = name
    self._is_enabled = _is_enabled(name)
end

function Logger:log(string)
    _log_implementation(self, "%s", 3, string)
end

function Logger:log_format(format, ...)
    _log_implementation(self, format, 3, ...)
end

function Logger:log_up(format, up, ...)
    _log_implementation(self, format, 3 + up, ...)
end

return Logger

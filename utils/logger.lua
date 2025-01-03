local Consts = require("app.consts")
local Model = require("data.model")
local Utils = require("utils.utils")

---@class LoggerData
---@field public start_time number

---@class Logger: Model
---@field public data LoggerData
---@field private _is_enabled boolean
---@field private _name string
---@field private _separator string
---@field private _start_time number
local Logger = class("Logger", Model)

---@param name string
---@return boolean
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

---@private
---@param format string
---@param level number
---@param ... any
function Logger:_log_implementation(format, level, ...)
    if not self._is_enabled then
        return
    end
    local sep = self._separator
    local time_diff = Utils.get_time() - self._start_time
    local result = string.format("%8.3f%s%21s", time_diff, sep, self._name)
    if debug then
        local info = debug.getinfo(level, "Sl")
        local location = string.format("%s:%i", info.short_src, info.currentline)
        result = result .. string.format("%s%44s", sep, location)
    end
    result = result .. string.format("%s>%s" .. format, sep, sep, ...)
    print(result)
end

---@param data LoggerData
---@param name string
function Logger:init(data, name)
    assert_type(name, "string")
    Model.init(self, data)
    self._name = name
    self.data.start_time = self.data.start_time or Utils.get_time()
    self._start_time = self.data.start_time
    self._separator = " "
    self._is_enabled = _is_enabled(name)
end

---@param name string
function Logger:set_name(name)
    assert_type(name, "string")
    self._name = name
    self._is_enabled = _is_enabled(name)
end

---@param string string
function Logger:log(string)
    self:_log_implementation("%s", 3, string)
end

---@param format string
---@param ... any
function Logger:log_format(format, ...)
    self:_log_implementation(format, 3, ...)
end

---@param format string
---@param up number
---@param ... any
function Logger:log_up(format, up, ...)
    self:_log_implementation(format, 3 + up, ...)
end

return Logger

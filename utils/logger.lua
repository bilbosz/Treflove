Logger = {}

local function IsEnabled(name)
    local n = #name
    for _, pattern in ipairs(Consts.LOGGER_NAME_BLACKLIST) do
        local start, stop = string.find(name, pattern)
        if start == 1 and stop == n then
            return false
        end
    end
    return true
end

function Logger:Init(data, name)
    assert(type(name) == "string")
    Model.Init(self, data)
    self.name = name
    self.data.startTime = self.data.startTime or GetTime()
    self.startTime = self.data.startTime
    self.separator = " "
    self.enable = IsEnabled(name)
end

function Logger:SetName(name)
    assert(type(name) == "string")
    self.name = name
    self.enable = IsEnabled(name)
end

function Logger:Log(format, ...)
    if not self.enable then
        return
    end
    local sep = self.separator
    local timeDiff = GetTime() - self.startTime
    local result = string.format("%8.3f%s%21s", timeDiff, sep, self.name)
    if debug then
        local info = debug.getinfo(2, "Sl")
        local location = string.format("%s:%i", info.short_src, info.currentline)
        result = result .. string.format("%s%44s", sep, location)
    end
    result = result .. string.format("%s>%s" .. format, sep, sep, ...)
    print(result)
end

MakeClassOf(Logger, Model)

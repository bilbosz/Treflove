Logger = {}

local socket = require("socket")

function Logger:Init(threadName)
    assert(type(threadName) == "string")
    self.threadName = threadName
    self.data.startTime = self.data.startTime or socket.gettime()
    self.startTime = self.data.startTime
    self.separator = " "
    self.enabled = true
end

function Logger:SetName(threadName)
    assert(type(threadName) == "string")
    self.threadName = threadName
end

function Logger:Log(format, ...)
    if not self.enabled then
        return
    end
    local sep = self.separator
    local timeDiff = socket.gettime() - self.startTime
    local result = string.format("%8.3f%s%21s", timeDiff, sep, self.threadName)
    if debug then
        local info = debug.getinfo(2, "Sl")
        result = result .. string.format("%s%41s:%i", sep, info.short_src, info.currentline)
    end
    result = result .. string.format("%s>%s" .. format, sep, sep, ...)
    print(result)
end

MakeModelOf(Logger)

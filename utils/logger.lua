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

function Logger:Log(...)
    if not self.enabled then
        return
    end
    local n = select("#", ...)
    local sep = self.separator
    local timeDiff = socket.gettime() - self.startTime
    local result = string.format("%8.3f%s%21s", timeDiff, sep, self.threadName)
    if debug then
        local info = debug.getinfo(2, "Sl")
        result = result .. string.format("%s%41s:%i", sep, info.short_src, info.currentline)
    end
    result = result .. string.format("%s>%s", sep, sep)
    for i = 1, n do
        result = result .. tostring(select(i, ...))
        if i ~= n then
            result = result .. sep
        end
    end
    print(result)
end

MakeModelOf(Logger)

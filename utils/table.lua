function table.merge(self, other)
    for k, v in pairs(other) do
        self[k] = v
    end
    return self
end

function table.copy(self)
    local result = {}
    for k, v in pairs(self) do
        result[k] = v
    end
    return result
end

function table.tostring(self)
    local tableDisplay
    local valueDisplay = {
        ["nil"] = tostring,
        ["boolean"] = tostring,
        ["number"] = tostring,
        ["string"] = function(v)
            return "\"" .. v .. "\""
        end,
        ["function"] = nil,
        ["userdata"] = nil,
        ["thread"] = nil,
        ["table"] = function(v)
            return tableDisplay(v)
        end
    }
    local keyDisplay = table.copy(valueDisplay)
    keyDisplay["nil"] = nil
    keyDisplay["table"] = nil

    local depth = 0
    local visited = {}
    tableDisplay = function(self)
        assert(type(self) == "table")
        assert(not visited[self])
        visited[self] = true
        depth = depth + 1
        local prefix = string.rep("    ", depth)
        local result = "{"
        for k, v in pairs(self) do
            local kType = type(k)
            local vType = type(v)
            local kDisplay = keyDisplay[kType]
            local vDisplay = valueDisplay[vType]
            if kDisplay and vDisplay then
                result = result .. "\n" .. prefix .. "[" .. kDisplay(k) .. "] = " .. vDisplay(v) .. ","
            end
        end
        depth = depth - 1
        prefix = string.rep("    ", depth)
        return result .. "\n" .. prefix .. "}"
    end

    local selfType = type(self)
    local selfDisplay = valueDisplay[selfType]
    assert(selfDisplay)
    return "return " .. selfDisplay(self)
end

function table.fromstring(s)
    local chunk = loadstring(s)
    local noError, result = pcall(chunk)
    if not noError then
        return nil
    end
    return result
end
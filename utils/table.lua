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

function table.deepcopy(self)
    local result = {}
    for k, v in pairs(self) do
        if type(v) == "table" then
            result[k] = table.deepcopy(v)
        else
            result[k] = v
        end
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
            return "\"" .. string.gsub(v, "\n", "\\n") .. "\""
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
        local nums = {}
        local strings = {}
        local others = {}
        for k, v in pairs(self) do
            local kType = type(k)
            local vType = type(v)
            if kType == "number" then
                table.insert(nums, k)
            elseif kType == "string" then
                table.insert(strings, k)
            else
                table.insert(others, k)
            end
        end
        table.sort(strings)

        local prefix = string.rep("    ", depth)
        local result = "{"
        local last = 0
        for _, group in ipairs({
            nums,
            strings,
            others
        }) do
            for _, k in ipairs(group) do
                local v = self[k]
                local kType = type(k)
                local vType = type(v)
                local vDisplay = valueDisplay[vType]
                if vDisplay then
                    local kDisplay = keyDisplay[kType]
                    if kType == "number" and k == last + 1 then
                        result = result .. "\n" .. prefix .. vDisplay(v) .. ","
                        last = k
                    elseif kType == "string" and IsIdentifier(k) then
                        result = result .. "\n" .. prefix .. k .. " = " .. vDisplay(v) .. ","
                    elseif kDisplay then
                        result = result .. "\n" .. prefix .. "[" .. kDisplay(k) .. "] = " .. vDisplay(v) .. ","
                    end
                end
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

local function prev(t, i)
    if i <= 1 then
        return nil, nil
    else
        return i - 1, t[i - 1]
    end
end

function ripairs(t)
    return prev, t, #t + 1
end

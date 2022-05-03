local function DumpGenerator(config)
    if not config then
        return
    end

    local function createKeyword(keyword)
        return "[" .. keyword .. "]\n"
    end

    local function createStacktrace(config)
        local result = "\n[STACKTRACE]\n"
        local trace = debug.traceback()
        local lineNo = 1
        local ignoreHead = 3
        local found = 0
        while found do
            local prev = found
            found = string.find(trace, "\n", found + 1)
            local line = string.sub(trace, prev + 1, found)
            if lineNo > ignoreHead and not string.find(line, "boot%.lua") and not string.find(line, "%[C%]") then
                result = result .. line
            end
            lineNo = lineNo + 1
        end
        return result
    end

    local nodeTypes = {
        Value = 1,
        Index = 2,
        Key = 3
    }

    local nodeDisplays = {
        [nodeTypes.Value] = config.dump.valueDisplay,
        [nodeTypes.Index] = config.dump.indexDisplay,
        [nodeTypes.Key] = config.dump.keyDisplay
    }

    local function createDump(config, args, n)
        config.tableMaxLevel = config.tableMaxLevel or math.huge
        assert(not config.tableUnfoldRepeated or config.tableMaxLevel ~= math.huge)

        local function getGlobVarName(val, tab, recursionCheck, isFirstLayer)
            tab = tab or _G
            recursionCheck = recursionCheck or {}
            isFirstLayer = isFirstLayer == nil and true

            for varName, curVal in pairs(tab) do
                if curVal == val then
                    if type(varName) == "number" then
                        return "[" .. varName .. "]"
                    else
                        return (isFirstLayer and "" or ".") .. varName
                    end
                elseif type(curVal) == "table" then
                    if recursionCheck[curVal] then
                        return
                    else
                        recursionCheck[curVal] = true
                    end
                    local founding = getGlobVarName(val, curVal, recursionCheck, false)
                    if founding then
                        if type(varName) == "number" then
                            return "[" .. varName .. "]" .. founding
                        else
                            return (isFirstLayer and "" or ".") .. varName .. founding
                        end
                    end
                end
            end
        end

        local function dump(val, level, node, recursionCheck)
            local result = ""

            recursionCheck = recursionCheck or {}

            local indention = config.tableIndention and string.rep(config.tableIndention, level) or ""
            local valueIndention = node == nodeTypes.Value and "" or indention

            local type_ = type(val)
            local varName
            if config.showGlobalNames then
                varName = getGlobVarName(val)
            end
            local content

            if type_ == "table" and (config.tableUnfoldRepeated or not recursionCheck[val]) and node == nodeTypes.Value and level < config.tableMaxLevel then
                recursionCheck[val] = true
                content = valueIndention .. "{" .. config.tableNewline
                local lastIndex = 0
                for key, curVal in pairs(val) do
                    local keyType = type(key)
                    if keyType == "number" and key == lastIndex + 1 then
                        lastIndex = key
                        content = content .. dump(key, level + 1, nodeTypes.Index)
                    else
                        content = content .. dump(key, level + 1, nodeTypes.Key)
                    end
                    content = content .. dump(curVal, level + 1, nodeTypes.Value, recursionCheck) .. "," .. config.tableNewline
                end
                content = content .. indention .. "}"
            end
            return valueIndention .. nodeDisplays[node](val, type_, varName, content)
        end

        local result = "\n[DUMP]\n"
        for i = 1, n do
            result = result .. dump(args[i], 0, nodeTypes.Value) .. (i ~= n and config.separator or "")
        end
        return result
    end

    return function(...)
        local result = ""

        if config.keyword then
            result = result .. createKeyword(config.keyword)
        end

        if config.stacktrace then
            result = result .. createStacktrace(config.stacktrace)
        end

        if config.dump then
            local args = {
                ...
            }
            local n = select("#", ...)
            result = result .. createDump(config.dump, args, n)
        end

        if config.textProcessor then
            return config.textProcessor(result)
        else
            return result
        end
    end
end

local function IsIdentifier(str)
    local l = #str
    local b, e = string.find(str, "[%a_][%w_]*")
    return b == 1 and e == l
end

local function LongPrint(str)
    local limit = 3000
    local strlen = #str
    for i = 1, strlen, limit do
        res = string.sub(str, i, i + limit - 1)
        print(res)
    end
end

local defaultDumpConfig = {
    stacktrace = {},
    dump = {
        showGlobalNames = false,
        tableMaxLevel = nil,
        tableIndention = "    ",
        tableUnfoldRepeated = false,
        tableNewline = "\n",
        indexDisplay = function(value, type, globalName, content)
            return ""
        end,
        keyDisplay = function(value, type, globalName, content)
            if type == "table" or type == "userdata" or type == "function" or type == "thread" then
                return tostring(value)
            elseif type == "string" then
                if IsIdentifier(value) then
                    return value .. " = "
                else
                    return "[\"" .. value .. "\"] = "
                end
            else
                return "[" .. tostring(value) .. "] = "
            end
        end,
        valueDisplay = function(value, type, globalName, content)
            if type == "table" then
                return content and content or tostring(value)
            elseif type == "string" then
                return "\"" .. tostring(value) .. "\""
            else
                return tostring(value)
            end
        end,
        separator = ",\n"
    },
    textProcessor = print
}

dump = DumpGenerator(defaultDumpConfig)

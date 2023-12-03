local function DumpGenerator(config)
    if not config then
        return
    end

    local function create_keyword(keyword)
        return "[" .. keyword .. "]\n"
    end

    local function create_stacktrace(config)
        local result = "\n[STACKTRACE]\n"
        local trace = debug.traceback()
        local line_no = 1
        local ignore_head = 3
        local found = 0
        while found do
            local prev = found
            found = string.find(trace, "\n", found + 1)
            local line = string.sub(trace, prev + 1, found)
            if line_no > ignore_head and not string.find(line, "boot%.lua") and not string.find(line, "%[C%]") then
                result = result .. line
            end
            line_no = line_no + 1
        end
        return result
    end

    local node_types = {
        Value = 1,
        Index = 2,
        Key = 3
    }

    local node_displays = {
        [node_types.Value] = config.dump.value_display,
        [node_types.Index] = config.dump.index_display,
        [node_types.Key] = config.dump.key_display
    }

    local function create_dump(config, args, n)
        config.tableMaxLevel = config.tableMaxLevel or math.huge
        assert(not config.tableUnfoldRepeated or config.tableMaxLevel ~= math.huge)

        local function getGlobVarName(val, tab, recursion_check, isFirstLayer)
            tab = tab or _G
            recursion_check = recursion_check or {}
            isFirstLayer = isFirstLayer == nil and true

            for var_name, cur_val in pairs(tab) do
                if cur_val == val then
                    if type(var_name) == "number" then
                        return "[" .. var_name .. "]"
                    else
                        return (isFirstLayer and "" or ".") .. var_name
                    end
                elseif type(cur_val) == "table" then
                    if recursion_check[cur_val] then
                        return
                    else
                        recursion_check[cur_val] = true
                    end
                    local founding = getGlobVarName(val, cur_val, recursion_check, false)
                    if founding then
                        if type(var_name) == "number" then
                            return "[" .. var_name .. "]" .. founding
                        else
                            return (isFirstLayer and "" or ".") .. var_name .. founding
                        end
                    end
                end
            end
        end

        local function dump(val, level, node, recursion_check)
            local result = ""

            recursion_check = recursion_check or {}

            local indention = config.table_indention and string.rep(config.table_indention, level) or ""
            local value_indention = node == node_types.Value and "" or indention

            local type_ = type(val)
            local var_name
            if config.showGlobalNames then
                var_name = getGlobVarName(val)
            end
            local content

            if type_ == "table" and (config.tableUnfoldRepeated or not recursion_check[val]) and node == node_types.Value and level < config.tableMaxLevel then
                recursion_check[val] = true
                content = value_indention .. "{" .. config.table_newline
                local last_index = 0
                for key, cur_val in pairs(val) do
                    local key_type = type(key)
                    if key_type == "number" and key == last_index + 1 then
                        last_index = key
                        content = content .. dump(key, level + 1, node_types.Index)
                    else
                        content = content .. dump(key, level + 1, node_types.Key)
                    end
                    content = content .. dump(cur_val, level + 1, node_types.Value, recursion_check) .. "," .. config.table_newline
                end
                content = content .. indention .. "}"
            end
            return value_indention .. node_displays[node](val, type_, var_name, content)
        end

        local result = "\n[DUMP]\n"
        for i = 1, n do
            result = result .. dump(args[i], 0, node_types.Value) .. (i ~= n and config.separator or "")
        end
        return result
    end

    return function(...)
        local result = ""

        if config.keyword then
            result = result .. create_keyword(config.keyword)
        end

        if config.stacktrace then
            result = result .. create_stacktrace(config.stacktrace)
        end

        if config.dump then
            local args = {
                ...
            }
            local n = select("#", ...)
            result = result .. create_dump(config.dump, args, n)
        end

        if config.text_processor then
            return config.text_processor(result)
        else
            return result
        end
    end

end

local function _is_identifier(str)
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
        table_indention = "    ",
        tableUnfoldRepeated = false,
        table_newline = "\n",
        index_display = function(value, type, global_name, content)
            return ""
        end,
        key_display = function(value, type, global_name, content)
            if type == "table" or type == "userdata" or type == "function" or type == "thread" then
                return tostring(value)
            elseif type == "string" then
                if _is_identifier(value) then
                    return value .. " = "
                else
                    return "[\"" .. value .. "\"] = "
                end
            else
                return "[" .. tostring(value) .. "] = "
            end
        end,
        value_display = function(value, type, global_name, content)
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
    text_processor = print
}

dump = DumpGenerator(defaultDumpConfig)

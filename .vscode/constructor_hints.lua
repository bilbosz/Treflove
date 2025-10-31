---@diagnostic disable

local guide = require("parser.guide")
local visualize = require("cli.visualize")
local inspect = require("inspect")


local CTOR_LABEL = "init"
local PARAM_PATTERN = "^-@param%s+(%S+)%s+(.*)$"
local CLASS_PATTERN = "^-@class%s+(%w+)%s*(:?.*)$"
local PAPAJ_OFFSET = 2137
local CLASS_FACTORY_NAME = "class"
local BIND_DOC_ACCEPT = {
    "local",
    "setlocal",
    "setglobal",
    "setfield",
    "setmethod" ,
    "setindex",
    "tablefield",
    "tableindex",
    "self",
    "function",
    "return",
    "...",
    "call",
}


---@generic K, V
---@param t table<K, V>|V[]
---@param value V
---@return K?, V?
local function find(t, value)
    for k, v in pairs(t) do
        if v == value then
            return k, v
        end
    end
    return nil, nil
end


---@generic K, V
---@param t table<K, V>|V[]
---@param cond fun(k: K, v: V): boolean?
---@return K?, V?
local function find_if(t, cond)
    for k, v in pairs(t) do
        if cond(k, v) then
            return k, v
        end
    end
    return nil, nil
end


---@generic V
---@param target_array V[]
---@param source_array V[]
local function merge_array(target_array, source_array)
    for _, v in ipairs(source_array) do
        target_array[#target_array + 1] = v
    end
end


---@generic T
---@param t T
---@return T
local function shallow_copy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end


---@param origin table|nil
---@return any
local function get_or_nil(origin, ...)
    local current = origin
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if current == nil or key == nil then
            return nil
        end
        current = current[key] or nil
    end
    return current
end


---@param ast parser.object
local function visualize_ast(ast)
    local dot_file = io.open("vis.dot", "w")
    visualize.visualizeAst(ast.state.lua, dot_file)
    -- dot -Tpng vis.dot > out.png # available via `brew install graphviz`
    io.close(dot_file)
end


---@param node parser.object
---@param indent string
local function print_node_short(node, indent)
    local name = guide.getKeyName(node)
    print(string.format("%s* %s%s %s %d-%d", indent, node.type, name and string.format(" %q", name) or "", tostring(node), node.start, node.finish))
end


---@param node parser.object
---@param indent string
local function print_node(node, indent)
    print_node_short(node, indent)
    for k, v in pairs(node) do
        if k == "state" and v.comms then
            print(string.format("%s    | %s", indent, inspect(v.comms)))
        else
            print(string.format("%s    | %q -> %s", indent, k, tostring(v)))
        end
    end
end


---@param ast parser.object
---@param indent string
---@param cb fun(ast: parser.object[], indent: string)
local function traverse_ast_detail(ast, indent, cb)
    if not ast then
        return
    end
    cb(ast, indent)
    guide.eachChild(ast, function(child)
        traverse_ast_detail(child, "    " .. indent, cb)
    end)
end


---@param ast parser.object
local function traverse_ast(ast)
    traverse_ast_detail(ast, "", print_node)
end


---@param a parser.object
---@param b parser.object
---@return boolean
local function parser_object_comparator(a, b)
    return a.start < b.start
end


---@param ast parser.object
---@param elems parser.object[]
---@return parser.comm[]?
local function append_comms(ast, elems)
    local raw_comms = get_or_nil(ast, "state", "comms")
    if not raw_comms then
        return nil
    end

    merge_array(elems, raw_comms)

    return raw_comms
end


---@param ast parser.object
---@param elems parser.object[]
local function append_nodes(ast, elems)
    guide.eachSourceTypes(ast, BIND_DOC_ACCEPT, function(node)
        elems[#elems + 1] = node
    end)
end


---@param node parser.object
---@return string?
local function get_class_name_annotation(node)
    if node.type ~= "comment.short" then
        return nil
    end
    return string.match(node.text, CLASS_PATTERN)
end


---@param node parser.object
---@return boolean
local function is_assign_node(node)
    return node.type == "local" or node.type == "setglobal"
end


---@param node parser.object
---@return boolean
local function is_class_construction(node)
    if node.type ~= "local" then
        return false
    end
    local function_name = get_or_nil(node, "value", "vararg", "node", 1)
    return function_name == CLASS_FACTORY_NAME
end


---@param node parser.object
---@return string?, string?
local function get_param_annotation(node)
    if node.type ~= "comment.short" then
        return nil, nil
    end
    return string.match(node.text, PARAM_PATTERN)
end


---@param node parser.object
---@return boolean
local function is_function_node(node)
    return node.type == "function"
end


---@param node parser.object
---@return boolean
local function is_ctor_node(node)
    local parent = get_or_nil(node, "parent")
    return parent.type == "setmethod" and get_or_nil(parent, "method", 1) == CTOR_LABEL
end


---@param function_node parser.object
---@return parser.object|nil
local function get_class_node(function_node)
    return get_or_nil(function_node, "parent", "node", "node")
end


---@param class_name string
---@param param_stack string[]
---@return string
local function create_overload_anntotation(class_name, param_stack)
    return "-@overload fun(" .. table.concat(param_stack, ", ") .. "): " .. class_name
end


---@param class_node parser.object
---@param raw_comms parser.object[]
---@param overload_annotation string
local function insert_overload_annotation(class_node, raw_comms, overload_annotation)
    local pos = class_node.start - PAPAJ_OFFSET
    raw_comms[#raw_comms + 1] = {
        type = "comment.short",
        start = pos,
        finish = pos,
        text = overload_annotation,
        virtual = true,
    }
end


---@param raw_comms parser.comm[]
---@param all_elems parser.object[]
local function handle_constructors(raw_comms, all_elems)
    local current_class_name = nil
    ---@type table<parser.object, string>
    local class_names = {}
    ---@type string[]
    local param_stack = {}

    for _, node in ipairs(all_elems) do
        local class_name_annotation = get_class_name_annotation(node)
        if class_name_annotation then
            current_class_name = class_name_annotation
            goto CONTINUE
        end

        if is_assign_node(node) then
            if is_class_construction(node) then
                class_names[node] = current_class_name
            end
            current_class_name = nil
            goto CONTINUE
        end

        local param_name, param_type = get_param_annotation(node)
        if param_name then
            param_stack[#param_stack + 1] = param_name .. ": " .. param_type
            goto CONTINUE
        end

        if is_function_node(node) then
            if is_ctor_node(node) then
                local class_node = get_class_node(node)
                local class_name = get_or_nil(class_names, class_node)
                if class_name then
                    local overload_annotation = create_overload_anntotation(class_name, param_stack)
                    print(class_name, overload_annotation)
                    insert_overload_annotation(class_node, raw_comms, overload_annotation)
                end
            end
            param_stack = {}
            goto CONTINUE
        end

        ::CONTINUE::
    end
end


-- Plugin's entry point
---@param ast parser.object
function OnTransformAst(uri, ast)
    ---@type parser.object[]
    local all_elems = {}
    local raw_comms = append_comms(ast, all_elems)
    if not raw_comms then
        return
    end
    append_nodes(ast, all_elems)
    table.sort(all_elems, parser_object_comparator)

    handle_constructors(raw_comms, all_elems)
end

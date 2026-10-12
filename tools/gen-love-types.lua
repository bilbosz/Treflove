-- tools/gen-love-types.lua: generates types/love.d.tl, the Teal declaration
-- of the LÖVE API, from the love-api submodule (lib/love-api, LÖVE 11.5).
--
--     luajit tools/gen-love-types.lua            # writes types/love.d.tl
--     luajit tools/gen-love-types.lua -o FILE    # writes FILE ("-": stdout)
--
-- Run from the repository root. The output is committed; it is regenerated,
-- never edited by hand: fix this generator instead.
--
-- Mapping (love-api -> Teal):
--   module love.X          nested `record X` of `global record love`
--   object type T          `interface T is <supertypes>` nested in `love`
--   enum E                 `enum E` nested in `love`
--   function variants      one field declaration per variant (Teal overloads)
--   argument with default  optional parameter `name?: T` (and every later one)
--   argument `...`         vararg parameter `...: T`; return `...` is `T...`
--   callbacks              assignable fields `love.load`, `love.draw`, ...,
--                          first variant only (an overloaded field cannot be
--                          assigned a single function)
--   "table"                {any:any}; love-api's field lists describe a
--                          table's shape but not whether it is an array or a
--                          record, so no named record is generated
--   "function"             function(...: any): any...
--   arguments/returns after a vararg
--                          `...: any` / `any...` (Teal cannot spell values
--                          after a vararg)
--   "Variant", "any", "light userdata", "cdata"
--                          any: these are LÖVE's dynamically typed values
--                          (channel messages, event arguments, touch ids)

package.path = "lib/love-api/?.lua;" .. package.path

local api = require("love_api")

local out_path = "types/love.d.tl"
do
    local i = 1
    while arg[i] do
        if arg[i] == "-o" and arg[i + 1] then
            out_path = arg[i + 1]
            i = i + 2
        else
            io.stderr:write("usage: luajit tools/gen-love-types.lua [-o FILE]\n")
            os.exit(2)
        end
    end
end

local KEYWORDS = {}
for word in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do
    KEYWORDS[word] = true
end

local out = {}
local function emit(line)
    out[#out + 1] = line
end

-- Every object type and enum name declared in `love`, to map argument types
-- and to catch a name declared twice.
local declared = {}

local SIMPLE = {
    number = "number",
    string = "string",
    boolean = "boolean",
    ["nil"] = "nil",
    table = "{any:any}",
    ["function"] = "function(...: any): any...",
    any = "any",
    Variant = "any",
    ["light userdata"] = "any",
    cdata = "any"
}

local function map_type(name)
    local parts = {}
    local seen = {}
    for part in (name .. " or "):gmatch("(.-) or ") do
        local mapped = SIMPLE[part]
        if not mapped then
            assert(declared[part], "unknown love-api type: " .. part)
            mapped = part
        end
        if mapped == "any" then
            return "any"
        end
        if not seen[mapped] then
            seen[mapped] = true
            parts[#parts + 1] = mapped
        end
    end
    return table.concat(parts, " | ")
end

local function param_name(name, used)
    local n = name:gsub("[^%w_]", "_")
    if n == "" or n:match("^%d") then
        n = "_" .. n
    end
    if KEYWORDS[n] then
        n = n .. "_"
    end
    local base, k = n, 1
    while used[n] do
        k = k + 1
        n = base .. k
    end
    used[n] = true
    return n
end

-- The Teal function type of one variant. `is_method` adds `self`.
local function function_type(variant, is_method)
    local params = {}
    local used = {
        self = true
    }
    if is_method then
        params[1] = "self"
    end
    local optional = false
    local arguments = variant.arguments or {}
    for i, a in ipairs(arguments) do
        local t = map_type(a.type)
        if a.name == "..." then
            if i < #arguments then
                -- parameters after a vararg (love.graphics.clear's flags)
                -- cannot be spelled in Teal: the whole tail is `...: any`
                params[#params + 1] = "...: any"
                break
            end
            params[#params + 1] = "...: " .. t
        else
            if a.default ~= nil then
                optional = true
            end
            params[#params + 1] = param_name(a.name, used) .. (optional and "?: " or ": ") .. t
        end
    end
    local rets = {}
    local returns = variant.returns or {}
    for i, r in ipairs(returns) do
        local t = map_type(r.type)
        if r.name == "..." then
            if i < #returns then
                -- values after a vararg return (love.data.unpack's index)
                -- cannot be spelled in Teal: the whole tail is `any...`
                rets[#rets + 1] = "any..."
                break
            end
            rets[#rets + 1] = t .. "..."
        else
            rets[#rets + 1] = t
        end
    end
    local s = "function(" .. table.concat(params, ", ") .. ")"
    if #rets == 1 then
        s = s .. ": " .. rets[1]
    elseif #rets > 1 then
        s = s .. ": (" .. table.concat(rets, ", ") .. ")"
    end
    return s
end

-- One field declaration per distinct variant signature.
local function emit_functions(functions, indent, is_method)
    for _, f in ipairs(functions or {}) do
        local seen = {}
        for _, v in ipairs(f.variants) do
            local t = function_type(v, is_method)
            if not seen[t] then
                seen[t] = true
                emit(indent .. f.name .. ": " .. t)
            end
        end
    end
end

-- Collect every object type and enum, in module order, sorted inside each
-- module so the output is stable.
local all_types = {}
local all_enums = {}
local function collect(types, enums)
    for _, t in ipairs(types or {}) do
        assert(not declared[t.name], "type declared twice: " .. t.name)
        declared[t.name] = true
        all_types[#all_types + 1] = t
    end
    for _, e in ipairs(enums or {}) do
        assert(not declared[e.name], "enum declared twice: " .. e.name)
        declared[e.name] = true
        all_enums[#all_enums + 1] = e
    end
end
collect(api.types, api.enums)
for _, m in ipairs(api.modules) do
    collect(m.types, m.enums)
end

emit("-- types/love.d.tl: the Teal declaration of the LÖVE " .. api.version .. " API.")
emit("-- GENERATED by tools/gen-love-types.lua from lib/love-api; do not edit by hand.")
emit("-- Regenerate from the repository root: luajit tools/gen-love-types.lua")
emit("")
emit("global record love")

emit("   -- Object types")
for _, t in ipairs(all_types) do
    local supers = t.supertypes or {}
    local head = "   interface " .. t.name
    if #supers > 0 then
        head = head .. " is " .. table.concat(supers, ", ")
    end
    emit(head)
    emit_functions(t.functions, "      ", true)
    emit("   end")
end

emit("")
emit("   -- Enums")
for _, e in ipairs(all_enums) do
    emit("   enum " .. e.name)
    for _, c in ipairs(e.constants) do
        emit("      " .. string.format("%q", c.name))
    end
    emit("   end")
end

emit("")
emit("   -- Modules")
for _, m in ipairs(api.modules) do
    emit("   record " .. m.name)
    emit_functions(m.functions, "      ", false)
    emit("   end")
end

emit("")
emit("   -- Functions of love itself")
emit_functions(api.functions, "   ", false)

emit("")
emit("   -- Callbacks (assigned by the program; first love-api variant)")
for _, c in ipairs(api.callbacks) do
    emit("   " .. c.name .. ": " .. function_type(c.variants[1], false))
end

emit("")
emit("   -- Fields set by boot.lua that love-api does not list")
emit("   _os: string")
emit("   _version: string")
emit("   _version_major: number")
emit("   _version_minor: number")
emit("   _version_revision: number")
emit("   handlers: {string: function(...: any)}  -- event name -> handler; arguments are event-specific")
emit("end")
emit("")

local text = table.concat(out, "\n")
if out_path == "-" then
    io.write(text)
else
    local f = assert(io.open(out_path, "wb"))
    f:write(text)
    f:close()
end

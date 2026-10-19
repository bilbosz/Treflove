-- editor/luals/cats.lua: Teal types as LuaCATS annotations, for
-- editor/luals/plugin.lua. The plugin finds where a `.tlt` file or a
-- `.d.tl` fragment writes a type (a local's type list, a function's
-- parameters and returns, a cast, a type declaration) and asks this
-- module to read the type's tokens and to spell it as the Lua language
-- server reads types, in its annotations (LuaCATS: `---@class`,
-- `---@field`, `---@alias`, `---@type`, `---@param`, `---@return`,
-- `--[[@as T]]`). The analysis stays the server's: an annotation is a
-- comment, and the rewrite is never run.
--
-- Teal's types and their spelling here:
--
--   integer, number, string, boolean, any, nil, thread, userdata
--                              the same name
--   Name.Name<T>               the same name, resolved against the nested
--                              types of the enclosing records (`Image`
--                              inside `record love` is `love.Image`)
--   {T}                        T[]        (`(A|B)[]` for a union or a function)
--   {K: V}                     table<K, V>
--   {A, B}                     [A, B]
--   A | B                      A|B
--   function(a: T, b?: U): R   fun(a: T, b?: U): R
--   function(T, U)             fun(_1: T, _2: U)   a parameter with no name
--   function(self)             fun(self: R)        `self` is the record read
--   function<T is C>(...)      T is spelled as C (`any` with no constraint)
--                              in a type; a function definition's own type
--                              arguments become `---@generic T: C` lines
--   function                   function
--
-- and a type declaration's entries:
--
--   record R is A, B           ---@class R: A, B
--   record R is {T}            ---@field [integer] T
--   name: T                    ---@field name T
--   record S ... end  (nested) ---@field S R.S, then ---@class R.S and its
--                              entries, then ---@class R again, so that the
--                              entries after it are R's
--   interface I ... end        ---@class R.I (no field: a type only)
--   enum E ... end             ---@alias R.E, one ---| "value" per value
--   type X = T                 ---@alias R.X T
--   metamethod, userdata       --- (a line that keeps the annotations
--                              together; the server has no spelling for them)
--
-- A top-level interface also gets `---@overload fun(...: any): I`: in
-- Treflove every class's instance type is an interface and the class
-- table is typed by it, so a call on it constructs an instance
-- (docs/types.md, "Classes"); a record is a module. A top-level record
-- is followed by its value (`R = {}`, `local R = {}`), an interface by
-- none: it is a type only, and the module declares the class table. The server reads the
-- annotations of a class from consecutive comment lines, so the
-- declaration's `end` reopens the enclosing class and the plugin turns
-- every blank line and comment inside a declaration into a `---` line.
--
-- Loaded by the plugin with loadfile; requires nothing.
---@diagnostic disable: need-check-nil
-- (`fail` raises, which the server cannot see: a token it reads after a
-- check is never nil)
local concat = table.concat

local cats = {}

local function is_symbol(t, v)
    return t ~= nil and t.type == "symbol" and t.value == v
end

local function is_keyword(t, v)
    return t ~= nil and t.type == "keyword" and t.value == v
end

local function is_word(t, v)
    return t ~= nil and t.type == "name" and t.value == v
end

------------------------------------------------------------------------
-- Reading a type
------------------------------------------------------------------------

-- The reader walks the plugin's token array from an index and returns
-- a node and the index of the first token it did not read. The tokens
-- were accepted by the Teal dialect of the transpiler's parser
-- (lib/lua-lifetime/lifetime/teal.lua, whose grammar this follows), so
-- a shape it does not expect is an error, which the plugin catches.

local parse_type

local function fail(what, t)
    error(("cats: expected %s at line %s"):format(what, t and t.line or "?"), 0)
end

local function expect(tokens, i, v)
    if not is_symbol(tokens[i], v) then
        fail("'" .. v .. "'", tokens[i])
    end
    return i + 1
end

local function name(tokens, i)
    local t = tokens[i]
    if t == nil or t.type ~= "name" then
        fail("a name", t)
    end
    return t.value, i + 1
end

-- The `>` that closes a list: the lexer reads `>>` as one token and the
-- Teal dialect respells it `>` in place for the inner list, leaving the
-- other `>` for the outer one; the token's text is still two characters.
local function close_angle(tokens, i)
    local t = tokens[i]
    if t == nil or not is_symbol(t, ">") then
        fail("'>'", t)
        return i
    end
    if t.stop ~= nil and t.stop - t.pos == 1 and not t.half then
        t.half = true
        return i
    end
    return i + 1
end

-- '<' item {',' item} '>'
local function angle_list(tokens, i, item)
    i = expect(tokens, i, "<")
    local list = {}
    local node
    node, i = item(tokens, i)
    list[1] = node
    while is_symbol(tokens[i], ",") do
        node, i = item(tokens, i + 1)
        list[#list + 1] = node
    end
    return list, close_angle(tokens, i)
end

-- typearg ::= Name ['is' type]
local function typearg(tokens, i)
    local n
    n, i = name(tokens, i)
    local node = {name = n}
    if is_word(tokens[i], "is") then
        node.constraint, i = parse_type(tokens, i + 1)
    end
    return node, i
end

-- partype ::= Name ['?'] ':' type | ['?'] type | '...' [':' type], each
-- optionally followed by '...'
local function partype(tokens, i)
    local t, ahead = tokens[i], tokens[i + 1]
    local p = {}
    if t.type == "name" and (is_symbol(ahead, "?") or is_symbol(ahead, ":")) then
        p.name = t.value
        i = i + 1
        if is_symbol(tokens[i], "?") then
            p.opt = true
            i = i + 1
        end
        if is_symbol(tokens[i], ":") then
            p.type, i = parse_type(tokens, i + 1)
        end
    elseif is_symbol(t, "?") then
        p.opt = true
        p.type, i = parse_type(tokens, i + 1)
    elseif is_symbol(t, "...") then
        p.name = "..."
        i = i + 1
        if is_symbol(tokens[i], ":") then
            p.type, i = parse_type(tokens, i + 1)
        end
    else
        p.type, i = parse_type(tokens, i)
    end
    if is_symbol(tokens[i], "...") then
        p.name = "..."
        i = i + 1
    end
    return p, i
end

-- After a comma in a return list without parentheses: does a parameter
-- follow (`Name ':'` or `Name '?'`), ending the list?
local function parameter_follows(tokens, i)
    local t, ahead = tokens[i], tokens[i + 1]
    return t ~= nil and t.type == "name" and (is_symbol(ahead, ":") or is_symbol(ahead, "?"))
end

-- retlist ::= ':' ('(' [typelist] ['...'] ')' | typelist ['...']); the
-- `:` is tokens[i]. Returns the list, whether it ends in `...`, and the
-- next index.
local function rets(tokens, i)
    i = i + 1
    local list, vararg = {}, false
    local paren = is_symbol(tokens[i], "(")
    if paren then
        i = i + 1
    end
    if not (paren and is_symbol(tokens[i], ")")) then
        local node
        node, i = parse_type(tokens, i)
        list[1] = node
        while is_symbol(tokens[i], ",") and (paren or not parameter_follows(tokens, i + 1)) do
            node, i = parse_type(tokens, i + 1)
            list[#list + 1] = node
        end
        if is_symbol(tokens[i], "...") then
            vararg = true
            i = i + 1
        end
    end
    if paren then
        i = expect(tokens, i, ")")
    end
    return list, vararg, i
end

-- functiontype ::= 'function' [typeargs] ['(' [partype {',' partype}] ')'
-- [retlist]]; the `function` is tokens[i].
local function function_type(tokens, i)
    i = i + 1
    local node = {k = "fn", params = {}, rets = {}}
    if is_symbol(tokens[i], "<") then
        node.typeargs, i = angle_list(tokens, i, typearg)
    end
    if not is_symbol(tokens[i], "(") then
        return {k = "function"}, i
    end
    i = i + 1
    if not is_symbol(tokens[i], ")") then
        local p
        p, i = partype(tokens, i)
        node.params[1] = p
        while is_symbol(tokens[i], ",") do
            p, i = partype(tokens, i + 1)
            node.params[#node.params + 1] = p
        end
    end
    i = expect(tokens, i, ")")
    if is_symbol(tokens[i], ":") then
        node.rets, node.rets_vararg, i = rets(tokens, i)
    end
    return node, i
end

-- basetype ::= nominal | '{' type {',' type} '}' | '{' type ':' type '}'
-- | functiontype | 'nil'
local function base_type(tokens, i)
    local t = tokens[i]
    if t == nil then
        fail("a type", nil)
    end
    if t.type == "name" then
        local path = {t.value}
        i = i + 1
        while is_symbol(tokens[i], ".") do
            path[#path + 1], i = name(tokens, i + 1)
        end
        local node = {k = "name", path = path}
        if is_symbol(tokens[i], "<") then
            node.args, i = angle_list(tokens, i, parse_type)
        end
        return node, i
    elseif is_keyword(t, "nil") then
        return {k = "nil"}, i + 1
    elseif is_keyword(t, "function") then
        return function_type(tokens, i)
    elseif is_symbol(t, "{") then
        local first
        first, i = parse_type(tokens, i + 1)
        local node
        if is_symbol(tokens[i], ",") then
            node = {k = "tuple", items = {first}}
            repeat
                node.items[#node.items + 1], i = parse_type(tokens, i + 1)
            until not is_symbol(tokens[i], ",")
        elseif is_symbol(tokens[i], ":") then
            node = {k = "map", key = first}
            node.value, i = parse_type(tokens, i + 1)
        else
            node = {k = "array", elem = first}
        end
        return node, expect(tokens, i, "}")
    end
    fail("a type", t)
end

-- type ::= '(' type ')' | basetype {'|' basetype}
function parse_type(tokens, i)
    if is_symbol(tokens[i], "(") then
        local node
        node, i = parse_type(tokens, i + 1)
        return node, expect(tokens, i, ")")
    end
    local node
    node, i = base_type(tokens, i)
    if is_symbol(tokens[i], "|") then
        local union = {k = "union", items = {node}}
        while is_symbol(tokens[i], "|") do
            union.items[#union.items + 1], i = base_type(tokens, i + 1)
        end
        return union, i
    end
    return node, i
end

cats.parse_type = parse_type

-- A type list, `type {',' type}`, from tokens[i] to `last` inclusive;
-- the tokens before the first type (a `:` or a `?`) are skipped.
function cats.parse_types(tokens, i, last)
    while i <= last and (is_symbol(tokens[i], ":") or is_symbol(tokens[i], "?")) do
        i = i + 1
    end
    local list = {}
    local node
    node, i = parse_type(tokens, i)
    list[1] = node
    while i <= last and is_symbol(tokens[i], ",") do
        node, i = parse_type(tokens, i + 1)
        list[#list + 1] = node
    end
    if i ~= last + 1 then
        fail("the end of the type", tokens[i])
    end
    return list
end

-- The parameters and returns of a function definition, from its hooks'
-- token ranges: the typeargs (`<...>`), each typed parameter (`?`, `:`
-- and the type), the vararg's type and the return list (`:` first).
function cats.parse_typeargs(tokens, first)
    local list = angle_list(tokens, first, typearg)
    return list
end

function cats.parse_rets(tokens, first)
    local list, vararg = rets(tokens, first)
    return list, vararg
end

------------------------------------------------------------------------
-- Reading a type declaration
------------------------------------------------------------------------

local parse_body

-- newtype ::= 'record' recordbody | 'interface' recordbody | 'enum'
-- enumbody | 'require' '(' LiteralString ')' {'.' Name} | type, for a
-- `type X = newtype`: a nested declaration (returned with the given name)
-- or a type.
local function newtype(tokens, i, decl)
    local t = tokens[i]
    if t.type == "name" then
        local word = t.value
        if word == "record" or word == "interface" or word == "enum" then
            decl.kind = word
            return parse_body(tokens, i + 1, decl)
        elseif word == "require" and is_symbol(tokens[i + 1], "(") then
            i = i + 2
            if tokens[i] == nil or tokens[i].type ~= "string" then
                fail("a string", tokens[i])
            end
            i = expect(tokens, i + 1, ")")
            while is_symbol(tokens[i], ".") do
                local _
                _, i = name(tokens, i + 1)
            end
            decl.type = {k = "name", path = {"any"}}
            decl.last = i - 1
            return decl, i
        end
    end
    decl.type, i = parse_type(tokens, i)
    decl.last = i - 1
    return decl, i
end

-- enumbody ::= {LiteralString} 'end'
local function enum_body(tokens, i, decl)
    decl.entries = {}
    while not is_keyword(tokens[i], "end") do
        local t = tokens[i]
        if t == nil or t.type ~= "string" then
            fail("a string or 'end'", t)
        end
        decl.entries[#decl.entries + 1] = {kind = "value", raw = t.raw, first = i, last = i}
        i = i + 1
    end
    decl.last = i
    return decl, i + 1
end

-- recordbody ::= [typeargs] ['is' interfacelist] {recordentry} 'end';
-- tokens[i] is the first token after the name. A `where` clause or a
-- macroexp would need an expression read: an error.
function parse_body(tokens, i, decl)
    if decl.kind == "enum" then
        return enum_body(tokens, i, decl)
    end
    if is_symbol(tokens[i], "<") then
        decl.typeargs, i = angle_list(tokens, i, typearg)
    end
    decl.bases = {}
    if is_symbol(tokens[i], "{") then
        decl.array, i = parse_type(tokens, i + 1)
        i = expect(tokens, i, "}")
    end
    if is_word(tokens[i], "is") then
        i = i + 1
        if is_symbol(tokens[i], "{") then
            decl.array, i = parse_type(tokens, i + 1)
            i = expect(tokens, i, "}")
            while is_symbol(tokens[i], ",") do
                decl.bases[#decl.bases + 1], i = parse_type(tokens, i + 1)
            end
        else
            decl.bases[1], i = parse_type(tokens, i)
            while is_symbol(tokens[i], ",") do
                decl.bases[#decl.bases + 1], i = parse_type(tokens, i + 1)
            end
        end
    end
    if is_word(tokens[i], "where") then
        fail("no 'where' clause", tokens[i])
    end
    decl.header_last = i - 1
    decl.entries = {}
    decl.nested = {}
    while not is_keyword(tokens[i], "end") do
        local t = tokens[i]
        if t == nil or t.type == "eof" then
            fail("'end'", t)
        end
        local word = t.type == "name" and t.value
        local field = is_symbol(tokens[i + 1], ":")
        local entry
        if word == "userdata" and not field then
            entry = {kind = "userdata", first = i, last = i}
            i = i + 1
        elseif word == "type" and not field then
            entry = {kind = "type", first = i}
            entry.name, i = name(tokens, i + 1)
            i = expect(tokens, i, "=")
            entry, i = newtype(tokens, i, entry)
            decl.nested[entry.name] = true
        elseif (word == "record" or word == "interface" or word == "enum") and not field then
            entry = {kind = word, first = i}
            entry.name, i = name(tokens, i + 1)
            entry, i = parse_body(tokens, i, entry)
            decl.nested[entry.name] = true
        else
            entry = {kind = "field", first = i}
            if word == "metamethod" and not field then
                entry.kind = "meta"
                i = i + 1
            end
            if is_symbol(tokens[i], "[") then
                if tokens[i + 1] == nil or tokens[i + 1].type ~= "string" then
                    fail("a string", tokens[i + 1])
                end
                entry.key = tokens[i + 1].raw
                i = expect(tokens, i + 2, "]")
            else
                entry.name, i = name(tokens, i)
            end
            i = expect(tokens, i, ":")
            entry.type, i = parse_type(tokens, i)
            if is_symbol(tokens[i], "=") then
                fail("no macroexp", tokens[i])
            end
            entry.last = i - 1
        end
        decl.entries[#decl.entries + 1] = entry
    end
    decl.last = i
    return decl, i + 1
end

-- A declaration whose kind word (`record`, `interface`, `enum`, `type`)
-- is tokens[i] and whose name follows. Returns the declaration (`first`
-- is i, `last` the index of its `end` or of its last token) and the next
-- index.
function cats.parse_declaration(tokens, i)
    local t = tokens[i]
    if t == nil or t.type ~= "name" then
        fail("a declaration", t)
    end
    local decl = {kind = t.value, first = i}
    decl.name, i = name(tokens, i + 1)
    if decl.kind == "type" then
        if not is_symbol(tokens[i], "=") then
            decl.type = {k = "name", path = {"any"}}
            decl.last = i - 1
            return decl, i
        end
        return newtype(tokens, i + 1, decl)
    end
    return parse_body(tokens, i, decl)
end

------------------------------------------------------------------------
-- Spelling a type
------------------------------------------------------------------------

-- `ctx`: `scopes`, a stack of {path = "love", nested = {Image = true}}
-- for the records being read (innermost last); `self_name`, the type
-- `self` means; `generics`, type argument names substituted in a type;
-- `module_of`, a function from the name of a local to the record type of
-- the module it was required as, or nil.

local format_type

local function resolve(path, ctx)
    local head = path[1]
    if ctx.generics and ctx.generics[head] then
        return ctx.generics[head]
    end
    local scopes = ctx.scopes
    local found = false
    if scopes then
        for s = #scopes, 1, -1 do
            local scope = scopes[s]
            if scope.nested[head] then
                head = scope.path .. "." .. head
                found = true
                break
            end
        end
    end
    if not found and #path > 1 and ctx.module_of then
        -- `mocks.AppMock`: a type nested in the record of a required
        -- module, named through the module's local.
        head = ctx.module_of(head) or head
    end
    if #path == 1 then
        return head
    end
    return head .. "." .. concat(path, ".", 2)
end

-- A type that needs parentheses as the element of an array.
local function needs_parens(node)
    return node.k == "union" or node.k == "fn"
end

local function format_fn(node, ctx)
    local inner = ctx
    if node.typeargs then
        local generics = {}
        if ctx.generics then
            for k, v in pairs(ctx.generics) do
                generics[k] = v
            end
        end
        for _, arg in ipairs(node.typeargs) do
            generics[arg.name] = arg.constraint and format_type(arg.constraint, ctx) or "any"
        end
        inner = setmetatable({generics = generics}, {__index = ctx})
    end
    local params = {}
    for n, p in ipairs(node.params) do
        local pname = p.name
        local ptype
        if pname == nil and p.type.k == "name" and #p.type.path == 1 and p.type.path[1] == "self" then
            -- `function(self, ...)`: Teal reads `self` as the record's type
            pname = "self"
        end
        pname = pname or ("_" .. n)
        if p.type then
            ptype = format_type(p.type, inner)
            if p.type.k == "fn" then
                ptype = "(" .. ptype .. ")" -- its returns would read as this function's
            end
        elseif pname == "self" then
            ptype = ctx.self_name or "any"
        else
            ptype = "any"
        end
        if p.opt and pname ~= "..." then
            pname = pname .. "?"
        end
        params[n] = pname .. ": " .. ptype
    end
    local text = "fun(" .. concat(params, ", ") .. ")"
    if #node.rets > 0 then
        local list = {}
        for n, r in ipairs(node.rets) do
            list[n] = format_type(r, inner)
            if r.k == "fn" then
                list[n] = "(" .. list[n] .. ")"
            end
        end
        text = text .. ": " .. concat(list, ", ")
    end
    return text
end

function format_type(node, ctx)
    local k = node.k
    if k == "name" then
        local path = node.path
        if #path == 1 and path[1] == "self" then
            return ctx.self_name or "any"
        end
        local text = resolve(path, ctx)
        if node.args and text == "metatable" then
            -- tl's `metatable<T>`: the server's `metatable` takes no argument
            return text
        end
        if node.args then
            local list = {}
            for n, a in ipairs(node.args) do
                list[n] = format_type(a, ctx)
            end
            text = text .. "<" .. concat(list, ", ") .. ">"
        end
        return text
    elseif k == "nil" then
        return "nil"
    elseif k == "function" then
        return "function"
    elseif k == "fn" then
        return format_fn(node, ctx)
    elseif k == "array" then
        local elem = format_type(node.elem, ctx)
        if needs_parens(node.elem) then
            elem = "(" .. elem .. ")"
        end
        return elem .. "[]"
    elseif k == "map" then
        return "table<" .. format_type(node.key, ctx) .. ", " .. format_type(node.value, ctx) .. ">"
    elseif k == "tuple" then
        local list = {}
        for n, item in ipairs(node.items) do
            list[n] = format_type(item, ctx)
        end
        return "[" .. concat(list, ", ") .. "]"
    elseif k == "union" then
        local list = {}
        for n, item in ipairs(node.items) do
            list[n] = format_type(item, ctx)
            if item.k == "fn" then
                list[n] = "(" .. list[n] .. ")"
            end
        end
        return concat(list, "|")
    end
    error("cats: unknown node " .. tostring(k), 0)
end

cats.format_type = format_type

function cats.format_types(list, ctx)
    local parts = {}
    for n, node in ipairs(list) do
        parts[n] = format_type(node, ctx)
    end
    return concat(parts, ", ")
end

-- The `---@generic` lines of a function definition's type arguments.
function cats.generic_lines(typeargs, ctx)
    local lines = {}
    for n, arg in ipairs(typeargs) do
        lines[n] = "---@generic " .. arg.name .. (arg.constraint and (": " .. format_type(arg.constraint, ctx)) or "")
    end
    return lines
end

------------------------------------------------------------------------
-- Spelling a declaration
------------------------------------------------------------------------

-- The annotations of a declaration, as a list of pieces {first, last,
-- lines}: the tokens first..last are replaced by the lines (joined on
-- their own lines by the plugin, at the indentation of the first token).
-- `path` is the declaration's full name, `outer` the enclosing record's
-- path or nil, `opts.is_local` whether a `local` declared it.
local function emit(decl, path, outer, ctx, opts, out)
    local kind = decl.kind
    local lines = {}
    local function piece(first, last)
        out[#out + 1] = {first = first, last = last, lines = lines}
        lines = {}
    end
    local function reopen()
        if outer then
            lines[#lines + 1] = "---@class " .. outer
        end
    end
    if kind == "type" then
        lines[1] = "---@alias " .. path .. " " .. format_type(decl.type, ctx)
        reopen()
        piece(decl.first, decl.last)
        return
    end
    if kind == "enum" then
        lines[1] = "---@alias " .. path
        piece(decl.first, decl.header_last or decl.first + 1)
        for _, value in ipairs(decl.entries) do
            lines[1] = "---| " .. value.raw
            piece(value.first, value.last)
        end
        reopen()
        if #lines == 0 then
            lines[1] = "---" -- the `end`: not a line of spaces only
        end
        piece(decl.last, decl.last)
        return
    end
    -- record or interface
    if opts.field_line then
        lines[#lines + 1] = opts.field_line
    end
    local header = "---@class " .. path
    if #decl.bases > 0 then
        local bases = {}
        for n, base in ipairs(decl.bases) do
            bases[n] = format_type(base, ctx)
        end
        header = header .. ": " .. concat(bases, ", ")
    end
    lines[#lines + 1] = header
    local scopes = {}
    for n, s in ipairs(ctx.scopes or {}) do
        scopes[n] = s
    end
    scopes[#scopes + 1] = {path = path, nested = decl.nested}
    local inner = setmetatable({scopes = scopes, self_name = path}, {__index = ctx})
    if decl.array then
        lines[#lines + 1] = "---@field [integer] " .. format_type(decl.array, inner)
    end
    piece(decl.first, decl.header_last)
    local entries = decl.entries
    local overloaded -- the piece of the field the same name repeats
    for e, entry in ipairs(entries) do
        local ekind = entry.kind
        if ekind == "field" then
            local key = entry.name
            if key == nil then
                key = "[" .. entry.key .. "]"
            end
            local previous = entries[e - 1]
            if previous ~= nil and previous.kind == "field" and previous.name ~= nil and previous.name == entry.name then
                -- An overload: the same name again. The server reads one
                -- field whose type is the union of the functions, each in
                -- parentheses.
                local line = overloaded.lines[#overloaded.lines]
                if overloaded.alternatives == 1 then
                    line = line:gsub("^(%-%-%-@field [^ ]+ )(.*)$", "%1(%2)")
                end
                overloaded.lines[#overloaded.lines] = line .. "|(" .. format_type(entry.type, inner) .. ")"
                overloaded.alternatives = overloaded.alternatives + 1
                lines[1] = "---"
                piece(entry.first, entry.last)
            else
                lines[1] = "---@field " .. key .. " " .. format_type(entry.type, inner)
                piece(entry.first, entry.last)
                overloaded = out[#out]
                overloaded.alternatives = 1
            end
        elseif ekind == "meta" or ekind == "userdata" then
            lines[1] = "---"
            piece(entry.first, entry.last)
        else
            local nested_opts = {}
            if ekind == "record" or (ekind == "type" and entry.kind == "record") then
                nested_opts.field_line = "---@field " .. entry.name .. " " .. path .. "." .. entry.name
            end
            emit(entry, path .. "." .. entry.name, path, inner, nested_opts, out)
        end
    end
    if outer == nil then
        if kind == "interface" then
            -- A type only, local or global: no value. The class table of
            -- the same name (`local X: X = class("X")`) is declared by
            -- the module, and a second local would be a redefinition.
            lines[#lines + 1] = "---@overload fun(...: any): " .. path
        elseif opts.is_local then
            lines[#lines + 1] = "local " .. path .. " = {}"
        else
            lines[#lines + 1] = path .. " = {}"
        end
    else
        reopen()
    end
    piece(decl.last, decl.last)
end

-- The pieces of a top-level declaration (`local`/`global` kind Name ...),
-- `decl` from parse_declaration; `is_local` says which.
function cats.emit_declaration(decl, is_local)
    local out = {}
    emit(decl, decl.name, nil, {scopes = {}}, {is_local = is_local}, out)
    return out
end

return cats

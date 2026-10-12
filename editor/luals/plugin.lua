-- editor/luals/plugin.lua: a plugin for the Lua language server (LuaLS,
-- the sumneko.lua extension of VS Code) that lets it read `.tlt` files,
-- Teal with the lifetime extension (docs/types.md, docs/lifetime.md).
--
-- The server parses Lua only. This plugin's OnSetText rewrites a `.tlt`
-- file into plain Lua of the same shape before the server parses it, and
-- returns the rewrite as a list of diffs, so that the server maps every
-- position back to the source for hover, go to definition and
-- diagnostics. The rewrite is for analysis only: it is never run, and the
-- build (tools/build.lua, through lua-lifetime and tl) is the only thing
-- that generates code. It is lua-lifetime's plugin for `.lt` files
-- (lib/lua-lifetime/editor/luals/plugin.lua) plus the stripping of
-- Teal's types; the ownership part is the same rewrite:
--
--   e @ a             e or a          `@` and `!@` are postfix operators of
--   f !@ a            f or a          the lowest precedence that chain to
--                                     the left; `or` is the Lua operator
--                                     with the same shape.
--   e @ (a, b)        e or (a or b)   the list form: its commas.
--   x @ a             local _ = x or a
--                                     the statement form: an expression is
--                                     not a statement, so it is assigned to
--                                     `_`, which the server never reports
--                                     as unused or redefined.
--   <first token>     local lifetime = require("lifetime") <first token>
--                                     the header the transpiler emits,
--                                     inserted when the file uses an anchor
--                                     or names `lifetime`, so that
--                                     `lifetime.*` resolves to the runtime
--                                     (lib/lua-lifetime/lifetime/init.lua,
--                                     through Lua.runtime.path).
--
-- Teal's additions are what the Teal dialect of lua-lifetime's parser
-- (lib/lua-lifetime/lifetime/teal.lua) reads: the plugin parses the file
-- with that parser, through a dialect of its own that records every token
-- the Teal dialect consumes, and deletes them, since each is part of a
-- type and nothing else. So the rewrite follows the grammar the build
-- reads, as it changes:
--
--   local x: T = e               local x = e        typelists of locals and
--   global x: T = e              x = e              globals; `global`
--   global x: T                  x = nil            itself; a declared
--                                                   global with no value
--   function f<T>(a: T, b?: U): R                   type arguments,
--                                function f(a, b)   parameter and return
--                                                   types, `?`; `...: T`;
--                                                   `<const>` and the
--                                                   other attributes
--   global function f(...)       function f(...)
--   e as T, e as (A, B)          e                  casts; `e is T` is `e`
--   {name: T = v}                {name = v}
--   local record R ... end       local R = {}       type declarations:
--   local interface I is A ...   local I = {}       record, interface,
--   global enum E ... end        E = {}             enum, type, macroexp
--   local type X = Y             local X = {}
--
-- A type is never interpreted: the declaration fragments (`.d.tl`) are
-- not read, so the analysis is Lua's, untyped. When the lexer stops at a
-- malformed token, the parser rejects the file (as it does while a line
-- is being typed), or the tokens cannot be aligned to the text, the
-- plugin returns nothing and the server sees the raw file.
-- editor/luals/check.lua runs this rewrite over every `.tlt` file of the
-- repository (./test-code.sh does) and checks that the result is
-- syntactically valid Lua.
--
-- The server loads this file with `load(text, name, "t", env)` where env
-- indexes the server's globals; OnSetText is the global it looks up.
-- editor/luals/check.lua loads it the same way under LuaJIT.
local sub, find = string.sub, string.find

-- The transpiler's lexer, parser and Teal dialect, found relative to this
-- file so that the plugin reads the grammar of the submodule it lives
-- with. loadfile, not require: the server has a package.loaded of its
-- own that this must not touch, and none of the three requires anything.
local here = (debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]")) or "."
local LIFETIME = here .. "/../../lib/lua-lifetime/lifetime/"
local lexer = assert(loadfile(LIFETIME .. "lexer.lua"))()
local parser = assert(loadfile(LIFETIME .. "parser.lua"))()
local teal = assert(loadfile(LIFETIME .. "teal.lua"))()

local HEADER = "local lifetime = require(\"lifetime\") "

-- The spelling of a token in the source: names, keywords and symbols
-- carry it in `value`, numbers and strings in `raw`.
local function spelling(t)
    local ty = t.type
    if ty == "number" or ty == "string" then
        return t.raw
    end
    return t.value
end

-- Skip whitespace and comments from position p; return the position of
-- the next token. Lua 5.1's llex.c: a comment is `--` followed by a long
-- bracket, to its closing bracket, or anything else to the end of the
-- line.
local function skip(text, p)
    while true do
        local _, e = find(text, "^[ \t\n\r\v\f]+", p)
        if e then
            p = e + 1
        end
        if sub(text, p, p + 1) ~= "--" then
            return p
        end
        local _, close, eq = find(text, "^%[(=*)%[", p + 2)
        if close then
            local _, stop = find(text, "]" .. eq .. "]", close + 1, true)
            if not stop then
                return #text + 1
            end
            p = stop + 1
        else
            local nl = find(text, "[\n\r]", p + 2)
            if not nl then
                return #text + 1
            end
            p = nl
        end
    end
end

-- Give every token its byte range in text (`pos`, `stop`, inclusive) by
-- walking the text alongside the token array. Returns false when a token
-- is not found where it should be, which means the walk and the lexer
-- disagree and the rewrite must not be trusted. Runs before the parse,
-- which may respell a `>>` token as `>` (the Teal dialect's
-- anglebracket_list).
local function align(tokens, text)
    local p = 1
    if sub(text, 1, 3) == "\239\187\191" then
        p = 4
    end
    if sub(text, p, p) == "#" then
        p = find(text, "[\n\r]", p) or #text + 1
    end
    for i = 1, #tokens do
        local t = tokens[i]
        local ty = t.type
        if ty == "eof" or ty == "error" then
            return true
        end
        p = skip(text, p)
        local s = spelling(t)
        if type(s) ~= "string" or sub(text, p, p + #s - 1) ~= s then
            return false
        end
        t.pos, t.stop = p, p + #s - 1
        p = p + #s
    end
    return true
end

local function is_symbol(t, v)
    return t ~= nil and t.type == "symbol" and t.value == v
end

local function is_keyword(t, v)
    return t ~= nil and t.type == "keyword" and t.value == v
end

local function is_anchorop(t)
    return t ~= nil and t.type == "symbol" and (t.value == "@" or t.value == "!@")
end

-- A token that can end a prefixexp, so that a `(`, `[`, `{` or string
-- after it is a call or an index on it.
local function ends_prefixexp(t)
    if t == nil then
        return false
    end
    local ty = t.type
    if ty == "name" or ty == "string" then
        return true
    end
    return ty == "symbol" and (t.value == ")" or t.value == "]" or t.value == "}")
end

-- tokens[i] is `)`, `]` or `}`: the index of its opener, or nil.
local function matching_open(tokens, i)
    local depth = 0
    for j = i, 1, -1 do
        local t = tokens[j]
        if t.type == "symbol" then
            local v = t.value
            if v == ")" or v == "]" or v == "}" then
                depth = depth + 1
            elseif v == "(" or v == "[" or v == "{" then
                depth = depth - 1
                if depth == 0 then
                    return j
                end
            end
        end
    end
    return nil
end

-- tokens[i] is `(`, `[` or `{`: the index of its closer, or nil.
local function matching_close(tokens, i)
    local depth = 0
    for j = i, #tokens do
        local t = tokens[j]
        if t.type == "symbol" then
            local v = t.value
            if v == "(" or v == "[" or v == "{" then
                depth = depth + 1
            elseif v == ")" or v == "]" or v == "}" then
                depth = depth - 1
                if depth == 0 then
                    return j
                end
            end
        end
    end
    return nil
end

-- tokens[i] is the last token of the left operand of an anchor operator.
-- Returns the index of the operand's first token, or nil when the
-- operand is not a prefixexp or a function (then it is no statement).
local function operand_start(tokens, i)
    if is_keyword(tokens[i], "end") then
        -- A function body: balance `end` against the keywords that take
        -- one. `while` and `for` close through their `do`.
        local depth = 0
        for j = i, 1, -1 do
            local t = tokens[j]
            if t.type == "keyword" then
                local v = t.value
                if v == "end" then
                    depth = depth + 1
                elseif v == "function" or v == "if" or v == "do" then
                    depth = depth - 1
                    if depth == 0 then
                        return v == "function" and j or nil
                    end
                end
            end
        end
        return nil
    end
    while true do
        local t = tokens[i]
        if t == nil then
            return nil
        end
        local ty, v = t.type, t.value
        if ty == "symbol" and (v == ")" or v == "]" or v == "}") then
            local o = matching_open(tokens, i)
            if o == nil then
                return nil
            end
            local q = tokens[o - 1]
            if tokens[o].value == "[" then
                if not ends_prefixexp(q) then
                    return nil
                end
                i = o - 1
            elseif ends_prefixexp(q) then
                i = o - 1 -- a call: `f(...)`, `f{...}`
            else
                return o -- `( exp )` or a table constructor
            end
        elseif ty == "string" then
            if ends_prefixexp(tokens[i - 1]) then
                i = i - 1 -- a call: `f"..."`
            else
                return i
            end
        elseif ty == "name" then
            local q = tokens[i - 1]
            if q ~= nil and q.type == "symbol" and (q.value == "." or q.value == ":") then
                i = i - 2
            else
                return i
            end
        else
            return i
        end
    end
end

-- Block keywords after which a statement starts.
local STATEMENT_BEFORE = {
    ["do"] = true,
    ["then"] = true,
    ["else"] = true,
    ["repeat"] = true,
    ["end"] = true,
    ["break"] = true,
    ["true"] = true,
    ["false"] = true,
    ["nil"] = true
}

-- Whether a statement starts after token p (nil: the start of the chunk).
-- `>` ends a statement only as the close of Teal type arguments (`local
-- x: Box<T>`), never in an expression.
local function statement_after(p)
    if p == nil then
        return true
    end
    local ty, v = p.type, p.value
    if ty == "name" or ty == "number" or ty == "string" then
        return true
    end
    if ty == "keyword" then
        return STATEMENT_BEFORE[v] == true
    end
    return ty == "symbol" and (v == ";" or v == ")" or v == "]" or v == "}" or v == "::" or v == "..." or v == ">")
end

-- The dialect the parser is given: the Teal dialect, with `new` wrapped
-- so that every token the Teal dialect consumes through the parser's
-- `advance` is recorded in `consumed` (by index), a type declaration in
-- `decl` (by the index of its kind word, or of `global`: the index of its
-- last token and the Lua that replaces it), and a declared global with
-- no value in `nilled` (by the index of its last token).
local function make_dialect(tokens, index, consumed, decl, nilled)
    local dialect = setmetatable({}, {
        __index = teal.dialect
    })
    function dialect.new(P)
        local advance, current = P.advance, P.current
        P.advance = function()
            consumed[index[current()]] = true
            return advance()
        end
        local D = teal.dialect.new(P)
        local type_operator, local_declaration, global_statement = D.type_operator, D.local_declaration, D.global_statement
        -- `as` and `is` were advanced over by the parser: delete them with
        -- the type that follows.
        D.type_operator = function(e, op, line)
            consumed[index[current()] - 1] = true
            return type_operator(e, op, line)
        end
        -- `local record R ... end`: the kind word to the `end` (or the
        -- type of a `local type X = T`) become `R = {}` after the `local`.
        D.local_declaration = function(line)
            local i = index[current()]
            local node = local_declaration(line)
            if node then
                decl[i] = {
                    last = index[current()] - 1,
                    text = tokens[i + 1].value .. " = {}"
                }
            end
            return node
        end
        -- `global`: the word is consumed (deleted). A type declaration
        -- becomes `R = {}` from the word on; `global function` keeps its
        -- `function`; `global x: T` with no value gets ` = nil`.
        D.global_statement = function(line)
            local i = index[current()]
            local node = global_statement(line)
            if node then
                local last = index[current()] - 1
                if node.tag == "Teal" then
                    decl[i] = {
                        last = last,
                        text = tokens[i + 2].value .. " = {}"
                    }
                elseif node.tag == "GlobalFunction" then
                    consumed[i + 1] = nil
                elseif node.tag == "Global" and #node.exprs == 0 then
                    nilled[last] = true
                end
            end
            return node
        end
        return D
    end
    return dialect
end

-- The rewrite of `text`: an array of diffs {start, finish, text} over
-- byte offsets (inclusive, 1-based), or nil when there is nothing to do
-- or the text cannot be read.
local function rewrite(text)
    local tokens = lexer.tokenize(text, "=tlt", true, "teal")
    if not align(tokens, text) then
        return nil
    end
    local n = #tokens
    local index = {}
    for i = 1, n do
        index[tokens[i]] = i
    end
    local consumed, decl, nilled = {}, {}, {}
    local ok = pcall(parser.parse, tokens, "=tlt", make_dialect(tokens, index, consumed, decl, nilled))
    if not ok then
        return nil
    end
    local prefix, replace = {}, {}
    local uses = false
    local changes = next(consumed) ~= nil or next(decl) ~= nil
    local first
    for i = 1, n do
        local t = tokens[i]
        if t.pos == nil then
            break
        end
        first = first or i
        if t.type == "name" and t.value == "lifetime" then
            uses = true
        elseif is_anchorop(t) then
            uses = true
            replace[i] = " or "
            -- The list form: `(` after the operator, its commas at depth 1.
            if is_symbol(tokens[i + 1], "(") then
                local close = matching_close(tokens, i + 1)
                if close ~= nil then
                    local depth = 0
                    for j = i + 2, close - 1 do
                        local u = tokens[j]
                        if u.type == "symbol" then
                            local v = u.value
                            if v == "(" or v == "[" or v == "{" then
                                depth = depth + 1
                            elseif v == ")" or v == "]" or v == "}" then
                                depth = depth - 1
                            elseif v == "," and depth == 0 then
                                replace[j] = " or "
                            end
                        end
                    end
                end
            end
            -- The statement form: the chain's first operator whose
            -- operand begins a statement.
            if i > 1 and not is_anchorop(tokens[i - 1]) then
                local start = operand_start(tokens, i - 1)
                if start ~= nil and not is_anchorop(tokens[start - 1]) and statement_after(tokens[start - 1]) then
                    prefix[start] = "local _ = "
                end
            end
        end
    end
    if first == nil or not (uses or changes) then
        return nil
    end
    local diffs = {}
    if uses then
        local header_at = tokens[first].pos
        if prefix[first] == nil and replace[first] == nil and not consumed[first] and decl[first] == nil then
            diffs[1] = {
                start = header_at,
                finish = header_at - 1,
                text = HEADER
            }
        else
            prefix[first] = HEADER .. (prefix[first] or "")
        end
    end
    local i = 1
    while i <= n do
        local t = tokens[i]
        if t.pos == nil then
            break
        end
        local d, p = decl[i], prefix[i]
        if d ~= nil then
            diffs[#diffs + 1] = {
                start = t.pos,
                finish = tokens[d.last].stop,
                text = (p or "") .. d.text
            }
            i = d.last
        elseif p ~= nil or replace[i] ~= nil or consumed[i] or nilled[i] then
            local body = consumed[i] and "" or replace[i] or spelling(t)
            diffs[#diffs + 1] = {
                start = t.pos,
                finish = t.stop,
                text = (p or "") .. body .. (nilled[i] and " = nil" or "")
            }
        end
        i = i + 1
    end
    return diffs
end

-- The server's hook. `uri` is the file's URI, `text` its contents.
function OnSetText(uri, text)
    if sub(uri, -4) ~= ".tlt" then
        return nil
    end
    local ok, diffs = pcall(rewrite, text)
    if ok then
        return diffs
    end
    if type(log) == "table" and type(log.warn) == "function" then
        log.warn("editor/luals/plugin.lua: " .. tostring(diffs))
    end
    return nil
end

-- For editor/luals/check.lua.
return {
    rewrite = rewrite
}

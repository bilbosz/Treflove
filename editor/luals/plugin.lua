-- editor/luals/plugin.lua: a plugin for the Lua language server (LuaLS,
-- the sumneko.lua extension of VS Code) that lets it read `.tlt` files,
-- Teal with the lifetime extension (docs/types.md, docs/lifetime.md),
-- and the `.d.tl` declaration fragments.
--
-- The server parses Lua only. This plugin's OnSetText rewrites a `.tlt`
-- file into plain Lua of the same shape before the server parses it, and
-- returns the rewrite as a list of diffs, so that the server maps every
-- position back to the source for hover, go to definition and
-- diagnostics. The rewrite is for analysis only: it is never run, and the
-- build (tools/build.lua, through lua-lifetime and tl) is the only thing
-- that generates code. It is lua-lifetime's plugin for `.lt` files
-- (lib/lua-lifetime/editor/luals/plugin.lua) plus the translation of
-- Teal's types into the server's annotations; the ownership part is the
-- same rewrite:
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
--   <file start>      local lifetime = require("lifetime")
--                                     the header the transpiler emits, on a
--                                     line of its own, inserted when the
--                                     file names `lifetime` (an anchor
--                                     alone becomes `or` and needs none),
--                                     so that `lifetime.*` resolves to
--                                     the runtime
--                                     (lib/lua-lifetime/lifetime/init.lua,
--                                     through Lua.runtime.path).
--
-- Teal's additions are what the Teal dialect of lua-lifetime's parser
-- (lib/lua-lifetime/lifetime/teal.lua) reads: the plugin parses the file
-- with that parser, through a dialect of its own that records every token
-- the Teal dialect consumes and where each type stands, deletes the
-- tokens, and writes each type back as the annotation the server reads
-- in its place (LuaCATS; the spelling of a type is editor/luals/cats.lua):
--
--   local x: T = e               ---@type T          a line before the
--                                local x = e         statement, for locals
--   global x: T = e              ---@type T          and globals; `global`
--                                x = e               itself goes; a declared
--   global x: T                  ---@type T          global with no value
--                                x = nil             is assigned nil
--   function f<T>(a: T, b?: U): R
--                                ---@generic T       lines before the
--                                ---@param a T       statement (`function
--                                ---@param b? U      f`, `local function f`,
--                                ---@return R        `X.f = function`, `local
--                                function f(a, b)    f = function`), or
--                                                    before the `function`
--                                                    of any other function
--                                                    expression; `...: T` is
--                                                    `---@param ... T`
--   global function f(...)       function f(...)     with the same lines
--   e as T, e as (A, B)          e --[[@as T]]       a cast (the first type
--                                                    of a tuple); `e is T`
--                                                    is `e`
--   {name: T = v}                {name = v}
--   local record R ... end       ---@class R         type declarations:
--                                ---@field f T       their entries, one
--                                local R = {}        line each (cats.lua
--   global record R ... end      ---@class R         lists the entries); a
--                                ...                 record is a value too
--                                R = {}
--   local interface I is A ...   ---@class I: A      an interface is a type
--   global interface I is A ...  ---@field ...       only, and callable: a
--                                ---@overload fun(...: any): I
--                                                    class table is typed
--                                                    by its instance's
--                                                    interface
--                                                    (docs/types.md)
--   global enum E ... end        ---@alias E
--                                ---| "value"
--   local type X = Y             ---@alias X Y
--
-- Deleting a type deletes the blanks it leaves at the end of a line or
-- doubled, so that the rewrite has no trailing space of its own.
--
-- Every rewritten file starts with a `---@diagnostic disable` line that
-- turns off the server's checks of values against the annotations (a
-- parameter, assignment or return of the wrong type, a missing field or
-- return, a field set twice): every Teal type admits nil, a module's
-- record is filled after `local m: M = {}`, and the build is the type
-- checker. What is undefined (a global, a field, a type) is reported.
--
-- The server reads the annotations of a declaration from consecutive
-- comment lines, so inside a declaration every blank line becomes `---`
-- and every comment on a line of its own becomes a `---` comment, which
-- the server shows as the description of what follows it; the comments
-- right above an annotated statement become `---` comments too. In a
-- `.d.tl` fragment, which is declarations only, every comment on a line
-- of its own becomes one.
--
-- When the lexer stops at a malformed token, the parser rejects the file
-- (as it does while a line is being typed), or the tokens cannot be
-- aligned to the text, the plugin returns nothing and the server sees
-- the raw file; a declaration cats.lua cannot read (a `where` clause, a
-- macroexp) becomes `R = {}` as before. editor/luals/check.lua runs this
-- rewrite over every `.tlt` and `.d.tl` file of the repository
-- (./test-code.sh does) and checks that the result is syntactically
-- valid Lua.
--
-- The server loads this file with `load(text, name, "t", env)` where env
-- indexes the server's globals; OnSetText is the global it looks up.
-- editor/luals/check.lua loads it the same way under LuaJIT.
local sub, find, concat = string.sub, string.find, table.concat

-- The transpiler's lexer, parser and Teal dialect, found relative to this
-- file so that the plugin reads the grammar of the submodule it lives
-- with. loadfile, not require: the server has a package.loaded of its
-- own that this must not touch, and none of the three requires anything.
local here = (debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]")) or "."
local LIFETIME = here .. "/../../lib/lua-lifetime/lifetime/"
local lexer = assert(loadfile(LIFETIME .. "lexer.lua"))()
local parser = assert(loadfile(LIFETIME .. "parser.lua"))()
local teal = assert(loadfile(LIFETIME .. "teal.lua"))()
local cats = assert(loadfile(here .. "/cats.lua"))()

local HEADER = "local lifetime = require(\"lifetime\")\n"

-- The server's checks of values against the annotations are off in a
-- rewritten file: every Teal type admits nil, a module's record is
-- filled after `local m: M = {}`, Client and Server both assign
-- `love.keypressed`, and the build is the type checker
-- (docs/development.md, "Editor Support"). What is undefined (a global,
-- a field, a type) is still reported.
local DISABLED = "---@diagnostic disable: param-type-mismatch, assign-type-mismatch, return-type-mismatch, cast-local-type, missing-return, missing-return-value, redundant-return-value, missing-fields, duplicate-set-field, need-check-nil\n\n"
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
-- line. Each comment is appended to `comments` as {pos, stop, long}, its
-- byte range inclusive.
local function skip(text, p, comments)
    while true do
        local _, e = find(text, "^[ \t\n\r\v\f]+", p)
        if e then
            p = e + 1
        end
        if sub(text, p, p + 1) ~= "--" then
            return p
        end
        local start = p
        local _, close, eq = find(text, "^%[(=*)%[", p + 2)
        if close then
            local _, stop = find(text, "]" .. eq .. "]", close + 1, true)
            if not stop then
                comments[#comments + 1] = {pos = start, stop = #text, long = true}
                return #text + 1
            end
            p = stop + 1
            comments[#comments + 1] = {pos = start, stop = stop, long = true}
        else
            local nl = find(text, "[\n\r]", p + 2)
            if not nl then
                comments[#comments + 1] = {pos = start, stop = #text}
                return #text + 1
            end
            p = nl
            comments[#comments + 1] = {pos = start, stop = nl - 1}
        end
    end
end

-- Give every token its byte range in text (`pos`, `stop`, inclusive) by
-- walking the text alongside the token array, and collect the comments
-- met on the way. Returns false when a token is not found where it
-- should be, which means the walk and the lexer disagree and the rewrite
-- must not be trusted. Runs before the parse, which may respell a `>>`
-- token as `>` (the Teal dialect's anglebracket_list).
local function align(tokens, text, comments)
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
        p = skip(text, p, comments)
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

-- tokens[i] is the last token of the left operand of an anchor operator
-- (or of the left side of an assignment). Returns the index of the
-- operand's first token, or nil when the operand is not a prefixexp or a
-- function (then it is no statement).
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

-- The whitespace that indents the line of byte position `pos`.
local function indent_of(text, pos)
    local ls = pos
    while ls > 1 and sub(text, ls - 1, ls - 1) ~= "\n" do
        ls = ls - 1
    end
    return (find(text, "^[ \t]*", ls)) and sub(text, ls, select(2, find(text, "^[ \t]*", ls))) or ""
end

-- The line (1-based) of byte position `pos`, counting newlines; the
-- tokens carry their line already, this is for positions between them.
local function line_of(text, pos)
    local n = 1
    local p = 1
    while true do
        local nl = find(text, "\n", p, true)
        if nl == nil or nl >= pos then
            return n
        end
        n = n + 1
        p = nl + 1
    end
end

-- The dialect the parser is given: the Teal dialect, with `new` wrapped
-- so that every token the Teal dialect consumes through the parser's
-- `advance` is recorded in `consumed` (by index), a type declaration in
-- `decl` (by the index of its `local` or `global`, `first`: `kind`, the
-- index of its kind word, `last`, the index of its last token, `text`,
-- the Lua that replaces it when its types cannot be read, and whether it
-- is local), a declared global with no value in `nilled` (by
-- the index of its last token), the type list of a local or global
-- declaration in `typelists`, the typed parts of every function
-- definition in `funcs`, and a cast's type in `casts` (by the index of
-- its `as`). The ranges are token indexes, inclusive.
local function make_dialect(tokens, index, rec)
    local consumed, decl, nilled = rec.consumed, rec.decl, rec.nilled
    local dialect = setmetatable({}, {
        __index = teal.dialect
    })
    function dialect.new(P)
        local advance, current = P.advance, P.current
        local function at()
            return index[current()]
        end
        P.advance = function()
            consumed[at()] = true
            return advance()
        end
        local D = teal.dialect.new(P)
        local type_operator, local_declaration, global_statement = D.type_operator, D.local_declaration, D.global_statement
        local typeargs, param, vararg, rets, typelist = D.typeargs, D.param, D.vararg, D.rets, D.typelist
        local func
        -- `as` and `is` were advanced over by the parser: delete them with
        -- the type that follows; a cast keeps its type.
        D.type_operator = function(e, op, line)
            local i = at() - 1
            consumed[i] = true
            local node = type_operator(e, op, line)
            if op == "as" then
                rec.casts[i] = {first = i + 1, last = at() - 1}
            end
            return node
        end
        -- `local record R ... end`: the kind word to the `end` (or the
        -- type of a `local type X = T`) become `R = {}` after the `local`.
        D.local_declaration = function(line)
            local i = at()
            local node = local_declaration(line)
            if node then
                decl[i - 1] = {
                    first = i - 1,
                    kind = i,
                    last = at() - 1,
                    text = "local " .. tokens[i + 1].value .. " = {}",
                    is_local = true
                }
            end
            return node
        end
        -- `global`: the word is consumed (deleted). A type declaration
        -- becomes `R = {}` from the word on; `global function` keeps its
        -- `function`; `global x: T` with no value gets ` = nil`.
        D.global_statement = function(line)
            local i = at()
            local node = global_statement(line)
            if node then
                local last = at() - 1
                if node.tag == "Teal" then
                    decl[i] = {
                        first = i,
                        kind = i + 1,
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
        -- A function definition's parts, in the order the parser's `body`
        -- asks for them: the type arguments at the `(` or `<` after the
        -- name (always asked, so it opens the record), each parameter,
        -- the vararg, the returns after the `)` (always asked: it closes
        -- the record).
        D.typeargs = function(node)
            local i = at()
            func = {open = i, params = {}}
            typeargs(node)
            if at() > i then
                func.typeargs = {first = i, last = at() - 1}
            end
        end
        D.param = function(p)
            local i = at()
            param(p)
            if at() > i then
                func.params[#func.params + 1] = {name = p.name, opt = p.opt ~= nil, first = i, last = at() - 1}
            end
        end
        D.vararg = function(node)
            local i = at()
            vararg(node)
            if at() > i then
                func.vararg = {first = i, last = at() - 1}
            end
        end
        D.rets = function(node)
            local i = at()
            rets(node)
            if at() > i then
                func.rets = {first = i, last = at() - 1}
            end
            rec.funcs[#rec.funcs + 1] = func
            func = nil
        end
        -- `: T1, T2` after the names of a local or global declaration.
        D.typelist = function(node)
            local i = at()
            typelist(node)
            if at() > i then
                rec.typelists[#rec.typelists + 1] = {colon = i, last = at() - 1}
            end
        end
        return D
    end
    return dialect
end

-- The index of the `function` keyword of the definition whose `(` or `<`
-- is tokens[open]: back over the name (`f`, `a.b.c`, `a.b:c`).
local function function_keyword(tokens, open)
    local j = open - 1
    while j >= 1 do
        local t = tokens[j]
        if is_keyword(t, "function") then
            return j
        end
        if not (t.type == "name" or is_symbol(t, ".") or is_symbol(t, ":")) then
            return nil
        end
        j = j - 1
    end
    return nil
end

-- The index of the `end` that closes the function whose keyword is
-- tokens[fkw], or nil. The tokens of types (`consumed`) are skipped: a
-- function type's `function` opens no block.
local function block_end(tokens, fkw, consumed)
    local depth = 0
    for j = fkw, #tokens do
        local t = tokens[j]
        if t.type == "keyword" and not consumed[j] then
            local v = t.value
            if v == "function" or v == "if" or v == "do" then
                depth = depth + 1
            elseif v == "end" then
                depth = depth - 1
                if depth == 0 then
                    return j
                end
            end
        end
    end
    return nil
end

-- The record type of the module `require(modpath)` returns, read from
-- its source (`return mocks` after `local mocks: Mocks = {}`) or its
-- declaration file (`return socket` after `local record socket`), or nil.
local ROOT = here .. "/../../"
local function module_type(modpath)
    local rel = modpath:gsub("%.", "/")
    for _, path in ipairs({ROOT .. rel .. ".tlt", ROOT .. rel .. ".d.tl", ROOT .. "types/" .. rel .. ".d.tl"}) do
        local f = io.open(path, "rb")
        if f then
            local source = f:read("*a")
            f:close()
            local returned = source:match("\nreturn%s+([%a_][%w_]*)%s*$")
            if returned then
                local typed = source:match("\nlocal%s+" .. returned .. "%s*:%s*([%a_][%w_.]*)")
                if typed then
                    return typed
                end
                if source:find("\nlocal%s+record%s+" .. returned .. "%f[^%w_]") or source:find("\nlocal%s+interface%s+" .. returned .. "%f[^%w_]") then
                    return returned
                end
            end
            return nil
        end
    end
    return nil
end

-- The rewrite of `text`: an array of diffs {start, finish, text} over
-- byte offsets (inclusive, 1-based), or nil when there is nothing to do
-- or the text cannot be read. `fragment` is true for a `.d.tl` file.
local function rewrite(text, fragment)
    local tokens = lexer.tokenize(text, "=tlt", true, "teal")
    local comments = {}
    if not align(tokens, text, comments) then
        return nil
    end
    local n = #tokens
    local index = {}
    for i = 1, n do
        index[tokens[i]] = i
    end
    local rec = {consumed = {}, decl = {}, nilled = {}, typelists = {}, funcs = {}, casts = {}}
    local consumed, decl, nilled = rec.consumed, rec.decl, rec.nilled
    local ok = pcall(parser.parse, tokens, "=tlt", make_dialect(tokens, index, rec))
    if not ok then
        return nil
    end
    local prefix, replace = {}, {}
    local uses, names = false, false
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
            -- as a value (`lifetime.destroy(x)`): inside a type
            -- (`lifetime.Reason`) the name is the annotation's
            names = names or not consumed[i]
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

    -- The annotations. `above[i]` marks a statement starting at token i
    -- whose comments right above become `---` comments; `pieces` are the
    -- replacements of a declaration's tokens, by the index of its first
    -- token; `spans` the byte ranges of the declarations, where blank
    -- lines and comments become `---` lines.
    local above, pieces, spans = {}, {}, {}
    local blanks_before = {}

    -- The modules required into untyped locals (`local mocks =
    -- require("tests.lib.mocks")`), for a type named through one
    -- (`mocks.AppMock`): the module's record type, read from its file.
    local requires = {}
    for i = 1, n - 6 do
        if is_keyword(tokens[i], "local") and tokens[i + 1].type == "name" and is_symbol(tokens[i + 2], "=") and tokens[i + 3].type == "name" and tokens[i + 3].value == "require" and is_symbol(tokens[i + 4], "(") and tokens[i + 5].type == "string" and is_symbol(tokens[i + 6], ")") then
            requires[tokens[i + 1].value] = tokens[i + 5].value
        end
    end
    local module_types = {}
    local function module_of(head)
        local modpath = requires[head]
        if modpath == nil then
            return nil
        end
        if module_types[modpath] == nil then
            module_types[modpath] = module_type(modpath) or false
        end
        return module_types[modpath] or nil
    end

    -- The type arguments of a generic function definition are known to
    -- the server in that function's own annotations only (`---@generic`):
    -- a type inside its body spells them as their constraint, or `any`.
    local generic_scopes = {}
    for _, f in ipairs(rec.funcs) do
        if f.typeargs then
            local fkw = function_keyword(tokens, f.open)
            local last = fkw and block_end(tokens, fkw, consumed)
            local ok_args, args = pcall(cats.parse_typeargs, tokens, f.typeargs.first)
            if last and ok_args then
                local generics = {}
                for _, arg in ipairs(args) do
                    generics[arg.name] = arg.constraint and cats.format_type(arg.constraint, {scopes = {}, module_of = module_of}) or "any"
                end
                generic_scopes[#generic_scopes + 1] = {first = fkw, last = last, generics = generics}
            end
        end
    end
    -- The context for a type at token k.
    local function ctx_at(k)
        local generics
        for _, scope in ipairs(generic_scopes) do
            if k > scope.first and k <= scope.last then
                generics = generics or {}
                for name, spelled in pairs(scope.generics) do
                    generics[name] = spelled
                end
            end
        end
        return {scopes = {}, module_of = module_of, generics = generics}
    end

    -- Lines before the statement at token i, at its indentation.
    local function annotate(i, lines)
        local indent = indent_of(text, tokens[i].pos)
        prefix[i] = (prefix[i] or "") .. concat(lines, "\n" .. indent) .. "\n" .. indent
        above[i] = true
    end

    for i, d in pairs(decl) do
        local ok_parse, parsed = pcall(cats.parse_declaration, tokens, d.kind)
        local list
        if ok_parse and parsed.last == d.last then
            local ok_emit, emitted = pcall(cats.emit_declaration, parsed, d.is_local)
            if ok_emit then
                list = emitted
            end
        end
        if list then
            local prev_line
            for _, piece in ipairs(list) do
                local start = tokens[piece.first].pos
                if piece.first == d.kind then
                    start = tokens[i].pos
                end
                local indent = indent_of(text, start)
                local body = concat(piece.lines, "\n" .. indent)
                if prev_line ~= nil and tokens[piece.first].line == prev_line then
                    body = "\n" .. indent .. body
                end
                pieces[#pieces + 1] = {start = start, finish = tokens[piece.last].stop, text = body}
                prev_line = tokens[piece.last].line
            end
            spans[#spans + 1] = {pos = tokens[i].pos, stop = tokens[d.last].stop}
            above[i] = true
        else
            pieces[#pieces + 1] = {start = tokens[i].pos, finish = tokens[d.last].stop, text = d.text}
        end
    end

    for _, tl in ipairs(rec.typelists) do
        local ok_types, types = pcall(cats.parse_types, tokens, tl.colon, tl.last)
        if ok_types then
            local ctx = ctx_at(tl.colon)
            local j = tl.colon - 1
            while j >= 1 do
                local t = tokens[j]
                if is_keyword(t, "local") or (t.type == "name" and t.value == "global" and consumed[j]) then
                    annotate(j, {"---@type " .. cats.format_types(types, ctx)})
                    break
                end
                if not (t.type == "name" or is_symbol(t, ",") or is_symbol(t, "<") or is_symbol(t, ">")) then
                    break
                end
                j = j - 1
            end
        end
    end

    for _, f in ipairs(rec.funcs) do
        local ctx = ctx_at(f.open - 1) -- outer generics: its own are declared
        local ok_lines, lines = pcall(function()
            local list = {}
            if f.typeargs then
                for _, line in ipairs(cats.generic_lines(cats.parse_typeargs(tokens, f.typeargs.first), ctx)) do
                    list[#list + 1] = line
                end
            end
            for _, p in ipairs(f.params) do
                if p.name ~= "_" then -- a placeholder, repeated in Teal
                    local node = cats.parse_types(tokens, p.first, p.last)[1]
                    list[#list + 1] = "---@param " .. p.name .. (p.opt and "?" or "") .. " " .. cats.format_type(node, ctx)
                end
            end
            if f.vararg then
                local node = cats.parse_types(tokens, f.vararg.first, f.vararg.last)[1]
                list[#list + 1] = "---@param ... " .. cats.format_type(node, ctx)
            end
            if f.rets then
                local rets, vararg = cats.parse_rets(tokens, f.rets.first)
                for k, node in ipairs(rets) do
                    list[#list + 1] = "---@return " .. cats.format_type(node, ctx) .. (vararg and k == #rets and " ..." or "")
                end
            end
            return list
        end)
        local fkw = function_keyword(tokens, f.open)
        if ok_lines and #lines > 0 and fkw ~= nil then
            local prev = tokens[fkw - 1]
            local s
            if is_keyword(prev, "local") then
                s = fkw - 1
            elseif prev ~= nil and prev.type == "name" and prev.value == "global" and consumed[fkw - 1] then
                s = fkw - 1
            elseif statement_after(prev) then
                s = fkw
            elseif is_symbol(prev, "=") then
                local j = fkw - 2
                while j >= 1 and consumed[j] do
                    j = j - 1
                end
                local start = operand_start(tokens, j)
                if start ~= nil then
                    if is_keyword(tokens[start - 1], "local") then
                        s = start - 1
                    elseif statement_after(tokens[start - 1]) then
                        s = start
                    end
                end
            end
            if s ~= nil then
                annotate(s, lines)
            else
                -- A function expression inside an expression (an
                -- argument, a table field): the lines go before its
                -- `function`, which moves to a line of its own; the
                -- blanks that stood before it would end the line it
                -- leaves, so they go (`blanks_before`).
                local indent = indent_of(text, tokens[fkw].pos)
                local own_line = find(sub(text, 1, tokens[fkw].pos - 1), "\n[ \t]*$") ~= nil or find(sub(text, 1, tokens[fkw].pos - 1), "^[ \t]*$") ~= nil
                local body = concat(lines, "\n" .. indent) .. "\n" .. indent
                if own_line then
                    prefix[fkw] = (prefix[fkw] or "") .. body
                else
                    prefix[fkw] = (prefix[fkw] or "") .. "\n" .. indent .. body
                    blanks_before[fkw] = true
                end
            end
        end
    end

    for i, c in pairs(rec.casts) do
        local ok_types, types = pcall(cats.parse_types, tokens, c.first, c.last)
        if ok_types then
            local spelled = cats.format_type(types[1], ctx_at(i))
            if sub(spelled, -1) == "]" then
                spelled = spelled .. " " -- `]]]` would close the comment early
            end
            replace[i] = "--[[@as " .. spelled .. "]]"
        end
    end

    local diffs = {}
    local header_at = 1
    if sub(text, 1, 3) == "\239\187\191" then
        header_at = 4
    end
    if sub(text, header_at, header_at) == "#" then
        header_at = (find(text, "\n", header_at, true) or #text) + 1
    end
    diffs[1] = {
        start = header_at,
        finish = header_at - 1,
        text = DISABLED .. (names and HEADER or "") -- an anchor alone is `or`: no header
    }
    for _, piece in ipairs(pieces) do
        diffs[#diffs + 1] = piece
    end

    -- A comment on a line of its own becomes a `---` comment: inside a
    -- declaration, right above an annotated statement, or anywhere in a
    -- fragment. A `--` comment that goes on with `@` would be read as an
    -- annotation: a `.` keeps it a comment.
    local function in_span(pos)
        for _, span in ipairs(spans) do
            if pos >= span.pos and pos <= span.stop then
                return true
            end
        end
        return false
    end
    local function in_piece(pos)
        for _, piece in ipairs(pieces) do
            if pos >= piece.start and pos <= piece.finish then
                return true
            end
        end
        return false
    end
    local function starts_line(pos)
        local ls = pos
        while ls > 1 and sub(text, ls - 1, ls - 1) ~= "\n" do
            ls = ls - 1
        end
        return find(sub(text, ls, pos - 1), "^[ \t]*$") ~= nil
    end
    local convert, describe = {}, {}
    local tails = {}
    for _, piece in ipairs(pieces) do
        local last = piece.text:match("[^\n]*$")
        if sub(last, 1, 3) == "---" then
            tails[#tails + 1] = piece
        end
    end
    for k, c in ipairs(comments) do
        if not c.long and sub(text, c.pos + 2, c.pos + 2) ~= "-" and not in_piece(c.pos) then
            c.line = line_of(text, c.pos)
            if starts_line(c.pos) then
                if fragment or in_span(c.pos) then
                    convert[k] = true
                end
            else
                -- A comment after an annotation on its line: its
                -- description, `# ...`.
                for _, piece in ipairs(tails) do
                    if piece.finish < c.pos and line_of(text, piece.finish) == c.line then
                        describe[k] = true
                        break
                    end
                end
            end
        end
    end
    if not fragment then
        -- The comments right above an annotated statement: consecutive
        -- lines up from the statement's line.
        local by_line = {}
        for k, c in ipairs(comments) do
            if c.line and starts_line(c.pos) then
                by_line[c.line] = k
            end
        end
        for i in pairs(above) do
            local line = tokens[i].line - 1
            while by_line[line] do
                convert[by_line[line]] = true
                line = line - 1
            end
        end
    end
    for k in pairs(convert) do
        local c = comments[k]
        local body = "---"
        if find(text, "^[ \t]*@", c.pos + 2) then
            body = "--- ."
        end
        diffs[#diffs + 1] = {start = c.pos, finish = c.pos + 1, text = body}
    end
    for k in pairs(describe) do
        local c = comments[k]
        diffs[#diffs + 1] = {start = c.pos, finish = c.pos + 1, text = "#"}
    end
    -- A blank line inside a declaration becomes `---`.
    for _, span in ipairs(spans) do
        local p = span.pos
        while true do
            local s, e = find(text, "\n[ \t]*\r?\n", p)
            if s == nil or s > span.stop then
                break
            end
            local at = e
            if sub(text, at - 1, at - 1) == "\r" then
                at = at - 1
            end
            diffs[#diffs + 1] = {start = at, finish = at - 1, text = "---"}
            p = e
        end
    end

    -- Where the deletion of the consumed token i starts: at the token,
    -- or at the blanks before it when deleting the token would leave them
    -- at the end of a line or doubled. That is the blanks between two
    -- deleted tokens (`f(): T` must not leave `f() `), and the blanks
    -- before a run of deleted tokens that ends its line (`f() : T`).
    -- Never the indentation of a line, and never the blanks between two
    -- tokens that stay (`x is {T}and y` keeps `x and y`).
    local function deleted_from(i)
        local t = tokens[i]
        local start = t.pos
        while start > 1 do
            local c = sub(text, start - 1, start - 1)
            if c ~= " " and c ~= "\t" then
                break
            end
            start = start - 1
        end
        if start == t.pos or start == 1 or sub(text, start - 1, start - 1) == "\n" then
            return t.pos
        end
        local before = tokens[i - 1]
        if before ~= nil and consumed[i - 1] and before.stop == start - 1 then
            return start
        end
        local j = i
        while consumed[j + 1] and decl[j + 1] == nil and prefix[j + 1] == nil do
            j = j + 1
        end
        for k = i, j do
            if replace[k] ~= nil or nilled[k] then
                return t.pos
            end
        end
        if find(text, "^[ \t]*\r?\n", tokens[j].stop + 1) or find(text, "^[ \t]*$", tokens[j].stop + 1) then
            return start
        end
        return t.pos
    end

    local i = 1
    while i <= n do
        local t = tokens[i]
        if t.pos == nil then
            break
        end
        local d, p = decl[i], prefix[i]
        if d ~= nil then
            if p ~= nil then
                diffs[#diffs + 1] = {start = t.pos, finish = t.pos - 1, text = p}
            end
            i = d.last
        elseif p ~= nil or replace[i] ~= nil or consumed[i] or nilled[i] then
            local body = replace[i] or (consumed[i] and "") or spelling(t)
            local start = t.pos
            if consumed[i] and p == nil then
                start = deleted_from(i)
            elseif blanks_before[i] then
                while start > 1 and find(sub(text, start - 1, start - 1), "[ \t]") do
                    start = start - 1
                end
            end
            diffs[#diffs + 1] = {
                start = start,
                finish = t.stop,
                text = (p or "") .. body .. (nilled[i] and " = nil" or "")
            }
        end
        i = i + 1
    end
    table.sort(diffs, function(a, b)
        if a.start ~= b.start then
            return a.start < b.start
        end
        return a.finish < b.finish
    end)
    return diffs
end

-- The server's hook. `uri` is the file's URI, `text` its contents.
function OnSetText(uri, text)
    local fragment
    if sub(uri, -4) == ".tlt" then
        fragment = false
    elseif sub(uri, -5) == ".d.tl" then
        fragment = true
    else
        return nil
    end
    local ok, diffs = pcall(rewrite, text, fragment)
    if ok then
        return diffs
    end
    ---@diagnostic disable-next-line: undefined-global
    if type(log) == "table" and type(log.warn) == "function" then
        ---@diagnostic disable-next-line: undefined-global
        log.warn("editor/luals/plugin.lua: " .. tostring(diffs))
    end
    return nil
end

-- For editor/luals/check.lua.
return {
    rewrite = rewrite
}

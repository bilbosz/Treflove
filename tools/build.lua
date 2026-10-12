-- tools/build.lua: the build. Every `X.tlt` of the source tree becomes
-- `build/X.lua` (plain Lua 5.1 for LÖVE and LuaJIT); it is also the type
-- checker. Run by ./build-code.sh from the repository root:
--
--     luajit tools/build.lua            # everything
--     luajit tools/build.lua FILE...    # check and generate only these .tlt
--                                       # files (every .tlt is still
--                                       # transpiled, for the requires)
--
-- Steps (docs/development.md, "The build"):
--
-- 1. Environment file. Every `*.d.tl` declaration fragment of the source
--    tree, sorted, is concatenated behind `local lifetime =
--    require("lifetime")` into build/types/env.tl, with a `-- @file PATH`
--    line before each fragment so that positions map back. One file,
--    because Teal resolves nominal type names lazily only within one file
--    and Treflove's types are cyclic through the global `app`.
-- 2. Transpile. lua-lifetime's pipeline with the Teal dialect turns
--    `X.tlt` into the Teal `build/tl/X.tl`, every statement on its source
--    line.
-- 3. Type-check and generate. One `tl` environment, with types/*.d.tl and
--    the environment file predefined, checks every `build/tl/X.tl` (a
--    `require("a.b")` resolves to `build/tl/a/b.tl`) and generates
--    `build/X.lua`. The environment file is also checked as a file of its
--    own, since `tl` drops the errors of a predefined module.
-- 4. Runtime. lib/lua-lifetime/lifetime/init.lua is copied to
--    build/lifetime/init.lua.
--
-- Errors are printed as `FILE:LINE:COL: message` (for a `.tlt` the line is
-- the source line and the column the generated Teal's) and the build exits
-- with status 1. A `tl` warning (an unused variable, a hint) is an error
-- too, except the two the class recipe causes (see is_expected_warning). Success prints one line, `N modules built`.
local RUN_PATH = "lib/lua-lifetime/?.lua;lib/lua-lifetime/?/init.lua;lib/tl/?.lua;"
package.path = RUN_PATH .. package.path

local tl = require("tl")
local cli = require("lifetime.cli")
require("lifetime.teal")

local BUILD = "build"
local GEN_TARGET = "5.1"
-- As lifetime/teal.lua compiles: every statement on its source line.
local GENERATE_OPTIONS = {
    preserve_indent = true,
    preserve_newlines = true,
    preserve_hashbang = false
}
-- Where `tl` looks for modules while checking (it replaces `.lua` with
-- `.d.tl` and `.tl`). Only the build's Teal, the host declarations and the
-- runtime's declaration: not `./?.lua`, where a `utils/x.d.tl` fragment
-- would be taken for the declaration of the module `utils.x`.
local CHECK_PATH = BUILD .. "/tl/?.lua;" .. BUILD .. "/types/?.lua;types/?.lua;lib/lua-lifetime/?.lua"

local failed = false

local function report(message)
    io.stderr:write(message, "\n")
    failed = true
end

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function lines_of(command)
    local p = assert(io.popen(command))
    local list = {}
    for line in p:lines() do
        list[#list + 1] = line
    end
    p:close()
    return list
end

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

local function write_file(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function dirname(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local function make_dirs(paths)
    local seen, list = {}, {}
    for _, p in ipairs(paths) do
        local d = dirname(p)
        if not seen[d] then
            seen[d] = true
            list[#list + 1] = shell_quote(d)
        end
    end
    if #list > 0 then
        os.execute("mkdir -p " .. table.concat(list, " "))
    end
end

-- Source files of the tree, sorted: not under lib/, build/ or any hidden
-- directory (.git/, an editor's or a tool's own tree).
local function find_sources(pattern)
    local files = lines_of("find . -name " .. shell_quote(pattern) .. " -not -path './lib/*' -not -path './" .. BUILD .. "/*' -not -path '*/.*/*' -type f")
    for i, f in ipairs(files) do
        files[i] = f:gsub("^%./", "")
    end
    table.sort(files)
    return files
end

------------------------------------------------------------------------
-- 1. The environment file
------------------------------------------------------------------------

local ENV_FILE = BUILD .. "/types/env.tl"
local ENV_HEADER = "local lifetime = require(\"lifetime\")"

-- `markers[i] = {line = L, path = P}`: the fragment P starts after line L.
local markers = {}

-- Fragments ordered so that a type named in an `is` clause (of an
-- interface or a record) is declared in an earlier fragment (or earlier in
-- the same one): Teal resolves other type names lazily within the file,
-- but not the interfaces a type is declared to be.
-- Otherwise sorted by path.
local function order_fragments(fragments)
    local declared_in = {}
    local texts = {}
    for _, path in ipairs(fragments) do
        local text = read_file(path)
        texts[path] = text
        for name in text:gmatch("global%s+interface%s+([%w_]+)") do
            declared_in[name] = path
        end
        for name in text:gmatch("global%s+record%s+([%w_]+)") do
            declared_in[name] = path
        end
    end
    local deps = {}
    for _, path in ipairs(fragments) do
        local list = {}
        for _, kind in ipairs({
            "interface",
            "record"
        }) do
            for bases in texts[path]:gmatch("global%s+" .. kind .. "%s+[%w_]+%s+is%s+([^\n]*)") do
                for name in bases:gmatch("[%a_][%w_%.]*") do
                    local from = declared_in[name]
                    if from and from ~= path then
                        list[#list + 1] = from
                    end
                end
            end
        end
        table.sort(list)
        deps[path] = list
    end
    local ordered, state = {}, {}
    local function visit(path)
        if state[path] == "done" then
            return
        end
        if state[path] == "visiting" then
            report("build: cyclic `is` between declaration fragments at " .. path)
            return
        end
        state[path] = "visiting"
        for _, d in ipairs(deps[path]) do
            visit(d)
        end
        state[path] = "done"
        ordered[#ordered + 1] = path
    end
    for _, path in ipairs(fragments) do
        visit(path)
    end
    return ordered
end

-- The names of the global types the fragments and the host declarations
-- declare: a local of such a name (a required class table or module
-- table, which shares the name of its type) shadows a type, not a value.
local global_types = {}

local function collect_global_types(text)
    for kind, name in text:gmatch("global%s+(%a+)%s+([%w_]+)") do
        if kind == "interface" or kind == "record" or kind == "enum" or kind == "type" then
            global_types[name] = true
        end
    end
end

local function write_env_file(fragments)
    local parts = {
        ENV_HEADER
    }
    local line = 1
    for _, path in ipairs(fragments) do
        local text = read_file(path)
        collect_global_types(text)
        if text:sub(-1) ~= "\n" then
            text = text .. "\n"
        end
        line = line + 1
        parts[#parts + 1] = "-- @file " .. path
        markers[#markers + 1] = {
            line = line,
            path = path
        }
        parts[#parts + 1] = text:sub(1, -2)
        local _, n = text:gsub("\n", "")
        line = line + n
    end
    write_file(ENV_FILE, table.concat(parts, "\n") .. "\n")
end

-- A position of the environment file as `fragment:line`.
local function env_position(y)
    local found
    for _, m in ipairs(markers) do
        if m.line < y then
            found = m
        else
            break
        end
    end
    if not found then
        return ENV_FILE, y
    end
    return found.path, y - found.line
end

------------------------------------------------------------------------
-- Positions of generated Teal back to the sources
------------------------------------------------------------------------

-- build/tl/X.tl -> X.tlt
local function source_of(filename)
    local rel = filename:match("^" .. BUILD .. "/tl/(.*)%.tl$")
    if rel then
        return rel .. ".tlt"
    end
    return filename
end

local function format_error(e, default_filename)
    local filename = e.filename or default_filename
    local y, x = e.y or 0, e.x or 0
    if filename == ENV_FILE then
        filename, y = env_position(y)
    else
        filename = source_of(filename)
    end
    return string.format("%s:%d:%d: %s", filename, y, x, e.msg)
end

local reported = {}

-- Lines of the generated Teal files, read once, for is_expected_warning.
local teal_lines = {}

local function teal_line(filename, y)
    local lines = teal_lines[filename]
    if not lines then
        lines = {}
        local f = io.open(filename, "rb")
        if f then
            for line in f:lines() do
                lines[#lines + 1] = line
            end
            f:close()
        end
        teal_lines[filename] = lines
    end
    return lines[y] or ""
end

-- Is `name` a local interface (declared on line y) that a class table of
-- the same name shadows (`local X: X = class("X", ...)`)?
local function is_local_class_interface(filename, y, name)
    if not teal_line(filename, y):match("^%s*local%s+interface%s+" .. name .. "%f[^%w_]") then
        return false
    end
    local class_table = "^%s*local%s+" .. name .. "%s*:%s*" .. name .. "%s*=%s*class%("
    for _, line in ipairs(teal_lines[filename]) do
        if line:match(class_table) then
            return true
        end
    end
    return false
end

-- Warnings the class recipe causes everywhere (docs/types.md, "Classes"),
-- which are therefore not reported: a class table shadowing the type of
-- its name (`local Control: Control = require("controls.control")`; the
-- type is global, or a local interface in a test, which tl then also
-- calls unused although the annotations after the class table use it)
-- and a super call (`Base.init(self)`).
local function is_expected_warning(w)
    if w.tag == "unused" then
        local name = w.msg:match("^unused type ([%w_]+): type interface ")
        return name ~= nil and is_local_class_interface(w.filename, w.y, name)
    end
    if w.tag == "redeclaration" then
        local name = w.msg:match("shadows previous declaration of '([%w_]+)'")
        if not name then
            return false
        end
        local y = tonumber(w.msg:match("originally declared at (%d+):"))
        if not y then
            -- tl names the position only when the shadowed name is local:
            -- a global is shadowed. A global type, by the required class
            -- table or module table of its name, is the recipe; a global
            -- value (`app`, `config`, `dump`, ...) is reported.
            return global_types[name] == true
        end
        return is_local_class_interface(w.filename, y, name)
    end
    return w.tag == "hint" and w.msg:find("invoked method as a regular function", 1, true) ~= nil
end

-- Report the syntax and type errors and the warnings of a check result,
-- once per result. The tree is clean of warnings, so a warning fails the
-- build like an error.
local function report_result(result, filename)
    if reported[result] then
        return
    end
    reported[result] = true
    for _, list in ipairs({
        result.syntax_errors or {},
        result.type_errors or {}
    }) do
        for _, e in ipairs(list) do
            report(format_error(e, filename))
        end
    end
    for _, w in ipairs(result.warnings or {}) do
        if not is_expected_warning(w) then
            report(format_error({
                filename = w.filename,
                y = w.y,
                x = w.x,
                msg = "warning (" .. w.tag .. "): " .. w.msg
            }, filename))
        end
    end
end

------------------------------------------------------------------------
-- The build
------------------------------------------------------------------------

local function main(argv)
    local clock = os.clock()

    local all_modules = find_sources("*.tlt")
    local modules = all_modules
    if #argv > 0 then
        modules = {}
        for _, a in ipairs(argv) do
            modules[#modules + 1] = (a:gsub("^%./", ""))
        end
    end
    local fragments = {}
    for _, f in ipairs(find_sources("*.d.tl")) do
        if not f:match("^types/") then
            fragments[#fragments + 1] = f
        end
    end
    local host_types = lines_of("ls types/*.d.tl 2>/dev/null")
    table.sort(host_types)
    for _, t in ipairs(host_types) do
        collect_global_types(read_file(t))
    end

    -- A full build starts from an empty tree, so nothing stale (the Lua of
    -- a deleted .tlt) can shadow a source; a partial one keeps the rest.
    if #argv == 0 then
        os.execute("rm -rf " .. shell_quote(BUILD))
    end
    local outputs = {
        ENV_FILE,
        BUILD .. "/lifetime/init.lua"
    }
    for _, m in ipairs(all_modules) do
        local base = m:gsub("%.tlt$", "")
        outputs[#outputs + 1] = BUILD .. "/tl/" .. base .. ".tl"
        outputs[#outputs + 1] = BUILD .. "/" .. base .. ".lua"
    end
    make_dirs(outputs)

    -- 1. the environment file
    write_env_file(order_fragments(fragments))

    -- 2. transpile every module (a required module must exist as Teal
    -- even when only some files were named)
    for _, m in ipairs(all_modules) do
        local ok, teal, err = pcall(cli.build, read_file(m), m, "teal")
        if not ok then
            teal, err = nil, m .. ": " .. tostring(teal)
        end
        if teal then
            write_file(BUILD .. "/tl/" .. m:gsub("%.tlt$", ".tl"), teal)
        else
            report(err)
        end
    end
    if failed then
        return 1
    end

    -- 3. type-check and generate
    package.path = CHECK_PATH
    local predefined = {}
    for _, t in ipairs(host_types) do
        predefined[#predefined + 1] = t:match("^types/(.*)%.d%.tl$")
    end

    -- The environment file as a file of its own, in an environment that
    -- has only the host declarations.
    local host_env, host_err = tl.new_env({
        defaults = {
            gen_target = GEN_TARGET
        },
        predefined_modules = predefined
    })
    if not host_env then
        report("build: " .. tostring(host_err))
        return 1
    end
    local env_result, env_err = tl.check_file(ENV_FILE, host_env)
    if not env_result then
        report("build: " .. tostring(env_err))
        return 1
    end
    report_result(env_result, ENV_FILE)
    if failed then
        return 1
    end

    predefined[#predefined + 1] = "env"
    local env, err = tl.new_env({
        defaults = {
            gen_target = GEN_TARGET
        },
        predefined_modules = predefined
    })
    if not env then
        report("build: " .. tostring(err))
        return 1
    end

    local built = 0
    for _, m in ipairs(modules) do
        local base = m:gsub("%.tlt$", "")
        local teal_path = BUILD .. "/tl/" .. base .. ".tl"
        local result, check_err = tl.check_file(teal_path, env)
        if not result then
            report(m .. ": " .. tostring(check_err))
        else
            local had_errors = (#(result.syntax_errors or {}) + #(result.type_errors or {})) > 0
            report_result(result, teal_path)
            if not had_errors and not failed then
                local code, gen_err = tl.generate(result.ast, GEN_TARGET, GENERATE_OPTIONS)
                if code then
                    write_file(BUILD .. "/" .. base .. ".lua", code)
                    built = built + 1
                else
                    report(m .. ": " .. tostring(gen_err))
                end
            end
        end
    end
    -- Modules checked only because a named one required them.
    local loaded = {}
    for name in pairs(env.loaded) do
        loaded[#loaded + 1] = name
    end
    table.sort(loaded)
    for _, name in ipairs(loaded) do
        report_result(env.loaded[name], "?")
    end
    if failed then
        return 1
    end

    -- 4. the runtime
    package.path = RUN_PATH .. package.path
    write_file(BUILD .. "/lifetime/init.lua", read_file("lib/lua-lifetime/lifetime/init.lua"))

    print(string.format("%d modules built (%.1f s)", built, os.clock() - clock))
    return 0
end

os.exit(main(arg))

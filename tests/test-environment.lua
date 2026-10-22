local test = require("tests.lib.test")
local environment = require("scripting.environment")

test.suite("environment")

---@return table<string, any>, string[]
local function create()
    ---@type string[]
    local lines = {}
    local env = environment.create({}, function(line)
        table.insert(lines, line)
    end)
    return env, lines
end

test.case("has the whitelisted standard library", function()
    local env = create()
    test.assert_eq(env.pairs, pairs)
    test.assert_eq(env.tostring, tostring)
    test.assert_eq(env.unpack, unpack)
    test.assert_eq(env.string.format, string.format)
    test.assert_eq(env.string.gsub, string.gsub)
    test.assert_eq(env.table.insert, table.insert)
    test.assert_eq(env.table.sort, table.sort)
    test.assert_eq(env.math.floor, math.floor)
    test.assert_eq(env.math.pi, math.pi)
    test.assert_eq(env.math.random, math.random)
    test.assert_eq(env.os.clock, os.clock)
    test.assert_eq(env.os.time, os.time)
    test.assert_eq(env._VERSION, _VERSION)
    test.assert_eq(env._G, env)
end)

test.case("has nothing that reaches the host", function()
    local env = create()
    for _, name in ipairs({
        "collectgarbage",
        "coroutine",
        "debug",
        "dofile",
        "getfenv",
        "io",
        "load",
        "loadfile",
        "loadstring",
        "module",
        "newproxy",
        "package",
        "require",
        "setfenv",
        "app",
        "love",
        "class",
        "lifetime"
    }) do
        test.assert_eq(env[name], nil, name)
    end
    test.assert_eq(env.string.dump, nil, "string.dump")
    test.assert_eq(env.math.randomseed, nil, "math.randomseed")
    for _, name in ipairs({
        "date",
        "execute",
        "exit",
        "getenv",
        "remove",
        "rename",
        "setlocale",
        "tmpname"
    }) do
        test.assert_eq(env.os[name], nil, "os." .. name)
    end
    for _, name in ipairs({
        "to_string",
        "from_string",
        "merge",
        "merge_array",
        "copy",
        "deep_copy",
        "find_table_key",
        "find_array_idx",
        "is_empty"
    }) do
        test.assert_eq(env.table[name], nil, "table." .. name)
    end
end)

test.case("the libraries are copies, one per environment", function()
    local a = create()
    local b = create()
    ---@type table<string, any>
    local real_string = string
    test.assert_true(a.string ~= real_string)
    test.assert_true(a.string ~= b.string)
    a.string.shout = string.upper
    a.string.format = false
    test.assert_eq(b.string.shout, nil)
    test.assert_eq(b.string.format, string.format)
    test.assert_eq(real_string.shout, nil)
    test.assert_eq(real_string.format, string.format)
end)

test.case("print writes the pieces tab-separated, nils included, to the output", function()
    local env, lines = create()
    env.print("a", 1, nil, true)
    env.print()
    test.assert_deep_eq(lines, {
        "a\t1\tnil\ttrue",
        ""
    })
end)

test.case("string.rep is capped at the string limit", function()
    local env = create()
    test.assert_eq(env.string.rep("ab", 3), "ababab")
    test.assert_eq(env.string.rep("ab", 2, "-"), "ab-ab")
    test.assert_eq(env.string.rep("x", "2"), "xx")
    test.assert_eq(#env.string.rep("x", 1024 * 1024), 1024 * 1024)
    test.assert_error(function()
        env.string.rep("x", 1024 * 1024 + 1)
    end, "one byte over")
    test.assert_error(function()
        env.string.rep("xx", 2 ^ 40)
    end, "a huge count")
    test.assert_error(function()
        env.string.rep("x", 1024 * 1024, "-")
    end, "the separator counts")
    test.assert_error(function()
        env.string.rep("x", "many")
    end, "a count that is no number")
end)

test.case("getmetatable reaches the metatable of a table only", function()
    local env = create()
    ---@type table<string, any>
    local mt = {}
    test.assert_eq(env.getmetatable(setmetatable({}, mt)), mt)
    test.assert_eq(env.getmetatable(setmetatable({}, {
        __metatable = "locked"
    })), "locked")
    test.assert_eq(env.getmetatable(""), nil)
    test.assert_eq(env.getmetatable(print), nil)
    test.assert_eq(env.getmetatable(1), nil)
    test.assert_eq(env.getmetatable(nil), nil)
end)

test.case("xpcall passes the results through and hands an error to the handler", function()
    local env = create()
    test.assert_deep_eq({
        env.xpcall(function(a, b)
            return a + b, nil, "last"
        end, error, 1, 2)
    }, {
        true,
        3,
        nil,
        "last"
    })
    ---@type string|nil
    local seen = nil
    test.assert_deep_eq({
        env.xpcall(function()
            error("boom", 0)
        end, function(err)
            seen = err
            return "handled " .. tostring(err)
        end)
    }, {
        false,
        "handled boom"
    })
    test.assert_eq(seen, "boom")
end)

test.case("the host's entries are shared, not copied, and win over the standard ones", function()
    local world = {
        tokens = {}
    }
    local function my_pairs()
    end
    local env = environment.create({
        world = world,
        pairs = my_pairs
    }, function()
    end)
    test.assert_eq(env.world, world)
    test.assert_eq(env.pairs, my_pairs)
    env.world.tokens.a = 1
    test.assert_eq(world.tokens.a, 1)
end)

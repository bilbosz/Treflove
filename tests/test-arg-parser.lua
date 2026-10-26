local test = require("tests.lib.test")
local arg_parser = require("app.arg-parser")

---@param app_type string
---@param address string
---@param port string
---@return ArgParserResult|nil
local function parse(app_type, address, port)
    return arg_parser.parse({
        "game_dir",
        app_type,
        address,
        port
    })
end

test.suite("arg_parser")

test.case("accepts valid server and client invocations", function()
    local params = parse("server", "localhost", "8080")
    test.assert_deep_eq(params, {
        app_type = "server",
        address = "localhost",
        port = "8080",
        headless = false
    })
    test.assert_eq(parse("client", "192.168.1.1", "1024").app_type, "client")
end)

test.case("rejects too few arguments", function()
    test.assert_eq(arg_parser.parse({}), nil)
    test.assert_eq(arg_parser.parse({
        "game_dir",
        "server",
        "localhost"
    }), nil)
end)

test.case("rejects unknown app types", function()
    test.assert_eq(parse("gm", "localhost", "8080"), nil)
    test.assert_eq(parse("", "localhost", "8080"), nil)
end)

test.case("validates IPv4 addresses", function()
    test.assert_true(parse("server", "10.0.0.1", "8080") ~= nil)
    test.assert_eq(parse("server", "999.0.0.1", "8080"), nil, "octet above 255")
    test.assert_eq(parse("server", "1.2.3", "8080"), nil, "too few octets")
    test.assert_eq(parse("server", "example.com", "8080"), nil, "host names other than localhost")
end)

test.case("validates the port range 1024-65535", function()
    test.assert_eq(parse("server", "localhost", "1023"), nil)
    test.assert_true(parse("server", "localhost", "1024") ~= nil)
    test.assert_true(parse("server", "localhost", "65535") ~= nil)
    test.assert_eq(parse("server", "localhost", "65536"), nil)
    test.assert_eq(parse("server", "localhost", "port"), nil)
end)

---@param ... string The arguments after the game directory
---@return ArgParserResult|nil
local function parse_args(...)
    return arg_parser.parse({
        "game_dir",
        ...
    })
end

test.case("leaves the options unset without any", function()
    local params = assert(parse("client", "localhost", "8080"))
    test.assert_eq(params.scenario, nil)
    test.assert_eq(params.console, nil)
    test.assert_eq(params.server_console, nil)
    test.assert_eq(params.identity, nil)
    test.assert_eq(params.fixture, nil)
    test.assert_false(params.headless)
end)

test.case("accepts every client option, in any order", function()
    local params = parse_args("client", "localhost", "8080", "--headless", "--identity", "smoke_1", "--scenario", "join-game", "--server-console", "9091", "--console", "9090")
    test.assert_deep_eq(params, {
        app_type = "client",
        address = "localhost",
        port = "8080",
        scenario = "join-game",
        console = "9090",
        server_console = "9091",
        identity = "smoke_1",
        headless = true
    })
end)

test.case("accepts every server option", function()
    local params = parse_args("server", "localhost", "8080", "--fixture", "scenarios/fixtures/basic", "--console", "9090", "--identity", "smoke", "--headless")
    test.assert_deep_eq(params, {
        app_type = "server",
        address = "localhost",
        port = "8080",
        console = "9090",
        identity = "smoke",
        fixture = "scenarios/fixtures/basic",
        headless = true
    })
end)

test.case("rejects an option on the wrong side", function()
    test.assert_eq(parse_args("server", "localhost", "8080", "--scenario", "join-game"), nil, "--scenario on the server")
    test.assert_eq(parse_args("server", "localhost", "8080", "--server-console", "9091"), nil, "--server-console on the server")
    test.assert_eq(parse_args("client", "localhost", "8080", "--fixture", "scenarios"), nil, "--fixture on the client")
end)

test.case("rejects an unknown option and a stray value", function()
    test.assert_eq(parse_args("client", "localhost", "8080", "--verbose"), nil)
    test.assert_eq(parse_args("client", "localhost", "8080", "-headless"), nil)
    test.assert_eq(parse_args("client", "localhost", "8080", "join-game"), nil)
    test.assert_eq(parse_args("client", "localhost", "8080", "--headless", "yes"), nil)
end)

test.case("rejects an option without its value", function()
    test.assert_eq(parse_args("client", "localhost", "8080", "--scenario"), nil, "the last argument")
    test.assert_eq(parse_args("client", "localhost", "8080", "--console", "--headless"), nil, "another option in its place")
    test.assert_eq(parse_args("client", "localhost", "8080", "--identity", ""), nil, "an empty value")
end)

test.case("rejects a repeated option", function()
    test.assert_eq(parse_args("client", "localhost", "8080", "--headless", "--headless"), nil)
    test.assert_eq(parse_args("client", "localhost", "8080", "--console", "9090", "--console", "9091"), nil)
end)

test.case("validates the console ports as the main port", function()
    test.assert_eq(parse_args("server", "localhost", "8080", "--console", "1023"), nil)
    test.assert_eq(parse_args("server", "localhost", "8080", "--console", "65536"), nil)
    test.assert_eq(parse_args("server", "localhost", "8080", "--console", "port"), nil)
    test.assert_eq(parse_args("server", "localhost", "8080", "--console", "65535").console, "65535")
    test.assert_eq(parse_args("client", "localhost", "8080", "--server-console", "1023"), nil)
    test.assert_eq(parse_args("client", "localhost", "8080", "--server-console", "1024").server_console, "1024")
end)

test.case("accepts a scenario or an identity of word characters, underscores and hyphens", function()
    test.assert_eq(parse_args("client", "localhost", "8080", "--scenario", "Join_game-2").scenario, "Join_game-2")
    test.assert_eq(parse_args("client", "localhost", "8080", "--identity", "loop-smoke").identity, "loop-smoke")
    for _, name in ipairs({
        "join game",
        "lib/steps",
        "../x",
        "x.lua",
        "zażółć"
    }) do
        test.assert_eq(parse_args("client", "localhost", "8080", "--scenario", name), nil, "scenario " .. name)
        test.assert_eq(parse_args("client", "localhost", "8080", "--identity", name), nil, "identity " .. name)
    end
end)

test.case("accepts a fixture that is a relative path without ..", function()
    for _, path in ipairs({
        "fixture",
        "scenarios/fixtures/basic",
        "a.b/c_d/e-f"
    }) do
        test.assert_eq(parse_args("server", "localhost", "8080", "--fixture", path).fixture, path, path)
    end
    for _, path in ipairs({
        "/scenarios/fixtures",
        "scenarios/../..",
        "..",
        "scenarios/fixtures/",
        "scenarios//fixtures",
        "scenarios\\fixtures",
        "sce narios"
    }) do
        test.assert_eq(parse_args("server", "localhost", "8080", "--fixture", path), nil, path)
    end
end)

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
        headless = false,
        follow = false
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
    test.assert_eq(params.peers, nil)
    test.assert_eq(params.chunk, nil)
    test.assert_eq(params.watch, nil)
    test.assert_eq(params.targets, nil)
    test.assert_false(params.headless)
    test.assert_false(params.follow)
end)

test.case("accepts every client option, in any order", function()
    local params = parse_args("client", "localhost", "8080", "--headless", "--identity", "smoke_1", "--scenario", "join-game", "--server-console", "9091", "--peers", "bob:9100", "--console", "9090")
    test.assert_deep_eq(params, {
        app_type = "client",
        address = "localhost",
        port = "8080",
        scenario = "join-game",
        console = "9090",
        server_console = "9091",
        identity = "smoke_1",
        headless = true,
        follow = false,
        peers = {
            bob = "9100"
        }
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
        headless = true,
        follow = false
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

test.case("accepts the peers as names with their console ports", function()
    test.assert_deep_eq(parse_args("client", "localhost", "8080", "--peers", "bob:9100").peers, {
        bob = "9100"
    })
    test.assert_deep_eq(parse_args("client", "localhost", "8080", "--peers", "bob:9100,Eve_2-x:65535,carol:1024").peers, {
        bob = "9100",
        ["Eve_2-x"] = "65535",
        carol = "1024"
    })
end)

test.case("rejects the peers on the server, a malformed entry, a bad port and a repeated name", function()
    test.assert_eq(parse_args("server", "localhost", "8080", "--peers", "bob:9100"), nil, "on the server")
    for _, peers in ipairs({
        "",
        "bob",
        "bob:",
        ":9100",
        "bob:9100,",
        ",bob:9100",
        "bob:9100,,eve:9101",
        "bob 9100",
        "bob:9100:9101",
        "bob=9100",
        "b ob:9100",
        "zażółć:9100",
        "bob:1023",
        "bob:65536",
        "bob:port",
        "bob:9100,bob:9101"
    }) do
        test.assert_eq(parse_args("client", "localhost", "8080", "--peers", peers), nil, peers)
    end
    test.assert_eq(parse_args("client", "localhost", "8080", "--peers", "bob:9100", "--peers", "eve:9101"), nil, "a repeated option")
end)

test.case("accepts a console with its chunk, the chunk from stdin without one or for -", function()
    test.assert_deep_eq(parse_args("console", "127.0.0.1", "9090", "return 1 + 1"), {
        app_type = "console",
        address = "127.0.0.1",
        port = "9090",
        chunk = "return 1 + 1",
        headless = false,
        follow = false
    })
    test.assert_deep_eq(parse_args("console", "localhost", "9090"), {
        app_type = "console",
        address = "localhost",
        port = "9090",
        headless = false,
        follow = false
    })
    test.assert_eq(parse_args("console", "localhost", "9090", "-").chunk, nil)
    test.assert_eq(parse_args("console", "localhost", "9090", "-1").chunk, "-1", "a single dash starts a chunk, not an option")
end)

test.case("accepts follow and watch on the console anywhere after the port", function()
    for _, args in ipairs({
        {
            "--follow",
            "log(true)"
        },
        {
            "log(true)",
            "--follow"
        }
    }) do
        local params = assert(parse_args("console", "localhost", "9090", unpack(args)))
        test.assert_eq(params.chunk, "log(true)", table.concat(args, " "))
        test.assert_true(params.follow, table.concat(args, " "))
    end
    local params = assert(parse_args("console", "localhost", "9090", "--watch", "app:get_time()"))
    test.assert_eq(params.watch, "app:get_time()")
    test.assert_eq(params.chunk, nil)
    test.assert_false(params.follow, "follow is the flag alone; a watch follows by itself")
    test.assert_true(parse_args("console", "localhost", "9090", "--follow", "--watch", "x").follow)
end)

test.case("rejects on the console a watch with a chunk, a second chunk, a repeated or valueless option", function()
    for _, args in ipairs({
        {
            "--watch",
            "x",
            "return 1"
        },
        {
            "return 1",
            "--watch",
            "x"
        },
        {
            "--watch",
            "x",
            "-"
        },
        {
            "return 1",
            "return 2"
        },
        {
            "--follow",
            "--follow"
        },
        {
            "--watch",
            "x",
            "--watch",
            "y"
        },
        {
            "--watch"
        },
        {
            "--watch",
            ""
        },
        {
            "--watch",
            "--follow"
        },
        {
            "--host",
            "localhost"
        },
        {
            "-- a comment"
        }
    }) do
        test.assert_eq(parse_args("console", "localhost", "9090", unpack(args)), nil, table.concat(args, " "))
    end
    test.assert_eq(parse_args("console", "localhost", "port"), nil, "a bad port")
    test.assert_eq(parse_args("console", "example.com", "9090"), nil, "a bad address")
end)

test.case("rejects the client and server options on the console and the console options elsewhere", function()
    for _, args in ipairs({
        {
            "--scenario",
            "join-game"
        },
        {
            "--console",
            "9091"
        },
        {
            "--server-console",
            "9091"
        },
        {
            "--identity",
            "smoke"
        },
        {
            "--fixture",
            "scenarios"
        },
        {
            "--headless"
        },
        {
            "--peers",
            "bob:9100"
        }
    }) do
        test.assert_eq(parse_args("console", "localhost", "9090", unpack(args)), nil, table.concat(args, " "))
    end
    for _, app_type in ipairs({
        "client",
        "server"
    }) do
        test.assert_eq(parse_args(app_type, "localhost", "8080", "--follow"), nil, "--follow on the " .. app_type)
        test.assert_eq(parse_args(app_type, "localhost", "8080", "--watch", "x"), nil, "--watch on the " .. app_type)
    end
end)

test.case("accepts a monitor with its targets in place of the port, its console and headless", function()
    test.assert_deep_eq(parse_args("monitor", "127.0.0.1", "client:9090,server:9091"), {
        app_type = "monitor",
        address = "127.0.0.1",
        targets = {
            client = "9090",
            server = "9091"
        },
        headless = false,
        follow = false
    })
    test.assert_deep_eq(parse_args("monitor", "localhost", "server:9091", "--headless", "--console", "9092"), {
        app_type = "monitor",
        address = "localhost",
        targets = {
            server = "9091"
        },
        console = "9092",
        headless = true,
        follow = false
    })
end)

test.case("rejects malformed monitor targets and the other options on the monitor", function()
    for _, targets in ipairs({
        "9090",
        "client",
        "client:",
        ":9090",
        "client:9090,",
        "client:1023",
        "client:9090,client:9091",
        "zażółć:9090"
    }) do
        test.assert_eq(parse_args("monitor", "localhost", targets), nil, targets)
    end
    test.assert_eq(parse_args("monitor", "localhost"), nil, "no targets")
    for _, args in ipairs({
        {
            "return 1"
        },
        {
            "--follow"
        },
        {
            "--watch",
            "x"
        },
        {
            "--scenario",
            "join-game"
        },
        {
            "--server-console",
            "9091"
        },
        {
            "--identity",
            "smoke"
        },
        {
            "--fixture",
            "scenarios"
        },
        {
            "--peers",
            "bob:9100"
        }
    }) do
        test.assert_eq(parse_args("monitor", "localhost", "client:9090", unpack(args)), nil, table.concat(args, " "))
    end
end)

test.case("takes a monitor's targets nowhere else: a port is a port", function()
    test.assert_eq(parse_args("client", "localhost", "client:9090"), nil)
    test.assert_eq(parse_args("console", "localhost", "client:9090"), nil)
end)

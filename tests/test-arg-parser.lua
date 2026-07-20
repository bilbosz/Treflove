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
        port = "8080"
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

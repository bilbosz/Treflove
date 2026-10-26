local test = require("tests.lib.test")
local ConsoleClient = require("utils.console-client")
local console_cli = require("tools.console")

---@return TestFakeSocket
local function make_socket()
    ---@class TestFakeSocket: ConsoleSocket
    ---@field arriving string[] What reaches the socket, one piece per `receive` call
    ---@field buffer string Arrived, not yet received
    ---@field peer_closed boolean The server closed: once the buffer is empty, `receive` says "closed"
    ---@field refuse boolean `connect` fails
    ---@field send_limit integer|nil At most this many bytes per `send`, the rest timing out
    ---@field sent string Everything sent
    ---@field address string|nil
    ---@field port integer|nil
    ---@field closed boolean
    ---@field timeouts (number|nil)[] The argument of every `settimeout`
    local fake = {
        arriving = {},
        buffer = "",
        peer_closed = false,
        refuse = false,
        send_limit = nil,
        sent = "",
        address = nil,
        port = nil,
        closed = false,
        timeouts = {}
    }

    ---@param address string
    ---@param port integer
    ---@return integer|nil, string|nil
    function fake:connect(address, port)
        self.address, self.port = address, port
        if self.refuse then
            return nil, "connection refused"
        end
        return 1, nil
    end

    ---@param value number|nil
    function fake:settimeout(value)
        table.insert(self.timeouts, value)
    end

    ---@param data string
    ---@param i integer|nil
    ---@return integer|nil, string|nil, integer|nil
    function fake:send(data, i)
        i = i or 1
        local j = #data
        if self.send_limit and j - i + 1 > self.send_limit then
            j = i + self.send_limit - 1
            self.sent = self.sent .. data:sub(i, j)
            return nil, "timeout", j
        end
        self.sent = self.sent .. data:sub(i, j)
        return j, nil, nil
    end

    ---@param pattern "*l"|integer
    ---@return string|nil, string|nil, string|nil
    function fake:receive(pattern)
        local piece = table.remove(self.arriving, 1)
        if piece then
            self.buffer = self.buffer .. piece
        end
        if pattern == "*l" then
            local newline = self.buffer:find("\n", 1, true)
            if newline then
                local line = self.buffer:sub(1, newline - 1)
                self.buffer = self.buffer:sub(newline + 1)
                return line, nil, nil
            end
        elseif type(pattern) == "number" and #self.buffer >= pattern then
            local data = self.buffer:sub(1, pattern)
            self.buffer = self.buffer:sub(pattern + 1)
            return data, nil, nil
        end
        local partial = self.buffer
        self.buffer = ""
        return nil, (self.peer_closed and #self.arriving == 0) and "closed" or "timeout", partial
    end

    function fake:close()
        self.closed = true
    end

    return fake
end

---@param kind string
---@param body string
---@return string
local function frame(kind, body)
    return string.format("%s %d\n%s", kind, #body, body)
end

---@param fake TestFakeSocket
---@return ConsoleClient
local function connect(fake)
    return ConsoleClient("9090", nil, function()
        return fake
    end)
end

test.suite("ConsoleClient")

test.case("connects to the port on 127.0.0.1 by default, or on the host given", function()
    local fake = make_socket()
    connect(fake)
    test.assert_eq(fake.address, "127.0.0.1")
    test.assert_eq(fake.port, 9090)
    local other = make_socket()
    ConsoleClient("9091", "localhost", function()
        return other
    end)
    test.assert_eq(other.address, "localhost")
    test.assert_eq(other.port, 9091)
end)

test.case("a refused connection raises and closes the socket", function()
    local fake = make_socket()
    fake.refuse = true
    test.assert_error(function()
        connect(fake)
    end)
    test.assert_true(fake.closed)
end)

test.case("a request sends an eval frame and returns the body of its ok reply", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.arriving = {
        frame("ok", "42\t{a = 1}")
    }
    local ok, body = client:request("return 42, {a = 1}")
    test.assert_eq(fake.sent, "eval 18\nreturn 42, {a = 1}")
    test.assert_true(ok)
    test.assert_eq(body, "42\t{a = 1}")
end)

test.case("an error reply returns false and the message", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.arriving = {
        frame("error", "console:1: boom\nstack traceback:\n\t[C]: in function 'error'")
    }
    local ok, body = client:request("error('boom')")
    test.assert_false(ok)
    test.assert_eq(body, "console:1: boom\nstack traceback:\n\t[C]: in function 'error'")
end)

test.case("an async frame arriving before the reply goes to the frame handler", function()
    local fake = make_socket()
    local client = connect(fake)
    ---@type string[][]
    local frames = {}
    client:set_frame_handler(function(kind, body)
        table.insert(frames, {
            kind,
            body
        })
    end)
    fake.arriving = {
        frame("watch", "hp\t3\t0.05\t10") .. frame("log", "a line"),
        frame("ok", "")
    }
    local ok, body = client:request("watch('hp', function() return 10 end)")
    test.assert_true(ok)
    test.assert_eq(body, "")
    test.assert_deep_eq(frames, {
        {
            "watch",
            "hp\t3\t0.05\t10"
        },
        {
            "log",
            "a line"
        }
    })
end)

test.case("a body may hold newlines and a sent chunk too", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.arriving = {
        frame("ok", "a\nb\n\nok 3\n")
    }
    local ok, body = client:request("local a = 1\nreturn a\n")
    test.assert_eq(fake.sent, "eval 21\nlocal a = 1\nreturn a\n")
    test.assert_true(ok)
    test.assert_eq(body, "a\nb\n\nok 3\n")
end)

test.case("a reply split over several receives is put together", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.arriving = {
        "o",
        "k 1",
        "1\nhel",
        "",
        "lo wor",
        "ld"
    }
    local ok, body = client:request("return 'hello world'")
    test.assert_true(ok)
    test.assert_eq(body, "hello world")
end)

test.case("a send that times out part of the way goes on from the last byte sent", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.send_limit = 4
    fake.arriving = {
        frame("ok", "")
    }
    client:request("return nil")
    test.assert_eq(fake.sent, "eval 10\nreturn nil")
end)

test.case("a request raises once its timeout passes without a reply", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.arriving = {
        "ok 5\nab"
    }
    test.assert_error(function()
        client:request("return 'abcde'", 0.01)
    end)
    test.assert_false(fake.closed, "a timeout keeps the connection")
end)

test.case("a request raises when the connection closes", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.peer_closed = true
    test.assert_error(function()
        client:request("return 1")
    end)
    test.assert_true(fake.closed)
    test.assert_error(function()
        client:request("return 1")
    end, "a request on a closed connection")
end)

test.case("a malformed header closes the connection and raises", function()
    local fake = make_socket()
    local client = connect(fake)
    fake.arriving = {
        "ok five\n"
    }
    test.assert_error(function()
        client:request("return 1")
    end)
    test.assert_true(fake.closed)
end)

test.case("poll dispatches what arrived and says whether the connection is open", function()
    local fake = make_socket()
    local client = connect(fake)
    ---@type string[]
    local bodies = {}
    client:set_frame_handler(function(kind, body)
        table.insert(bodies, kind .. " " .. body)
    end)
    test.assert_true(client:poll())
    fake.arriving = {
        frame("log", "one") .. "log 3\ntw"
    }
    test.assert_true(client:poll())
    test.assert_deep_eq(bodies, {
        "log one"
    })
    fake.arriving = {
        "o"
    }
    test.assert_true(client:poll())
    test.assert_deep_eq(bodies, {
        "log one",
        "log two"
    })
    fake.peer_closed = true
    test.assert_false(client:poll())
    test.assert_true(fake.closed)
end)

test.case("close closes the socket once", function()
    local fake = make_socket()
    local client = connect(fake)
    client:close()
    test.assert_true(fake.closed)
    fake.closed = false
    client:close()
    test.assert_false(fake.closed)
    test.assert_false(client:poll())
end)

test.suite("console CLI")

test.case("takes the port and the chunk, the chunk from stdin without one or for -", function()
    test.assert_deep_eq(console_cli.parse({
        "9391",
        "return 1"
    }), {
        port = "9391",
        chunk = "return 1",
        follow = false
    })
    test.assert_deep_eq(console_cli.parse({
        "9391"
    }), {
        port = "9391",
        follow = false
    })
    test.assert_deep_eq(console_cli.parse({
        "9391",
        "-"
    }), {
        port = "9391",
        follow = false
    })
end)

test.case("takes the host and follow anywhere: before the port, between the port and the chunk, after both", function()
    ---@type ConsoleCliOptions
    local expected = {
        host = "localhost",
        port = "9391",
        chunk = "log(true)",
        follow = true
    }
    for _, args in ipairs({
        {
            "--follow",
            "--host",
            "localhost",
            "9391",
            "log(true)"
        },
        {
            "9391",
            "--host",
            "localhost",
            "log(true)",
            "--follow"
        },
        {
            "9391",
            "log(true)",
            "--follow",
            "--host",
            "localhost"
        }
    }) do
        test.assert_deep_eq(console_cli.parse(args), expected, table.concat(args, " "))
    end
end)

test.case("takes watch before or after the port", function()
    local before = assert(console_cli.parse({
        "--watch",
        "app:get_time()",
        "9391"
    }))
    local after = assert(console_cli.parse({
        "9391",
        "--watch",
        "app:get_time()"
    }))
    test.assert_deep_eq(after, before)
end)

test.case("watch sends a watch of the expression under its own text and follows", function()
    local options = assert(console_cli.parse({
        "--watch",
        "app:get_time()",
        "9391"
    }))
    test.assert_true(options.follow)
    test.assert_eq(options.chunk, console_cli.watch_chunk("app:get_time()"))
    ---@type string, fun(): any
    local name, fn
    local chunk = assert(loadstring(assert(options.chunk)))
    debug.setfenv(chunk, {
        watch = function(n, f)
            name, fn = n, f
        end,
        app = {
            get_time = function()
                return 1.5
            end
        }
    })
    chunk()
    test.assert_eq(name, "app:get_time()")
    test.assert_eq(fn(), 1.5)
end)

test.case("refuses a missing or bad port, an unknown, repeated or valueless option, extra arguments", function()
    for _, args in ipairs({
        {},
        {
            "port"
        },
        {
            "0"
        },
        {
            "65536"
        },
        {
            "--verbose",
            "9391"
        },
        {
            "9391",
            "--host"
        },
        {
            "9391",
            "return 1",
            "--watch"
        },
        {
            "9391",
            "--follow",
            "--follow"
        },
        {
            "--follow",
            "--follow",
            "9391"
        },
        {
            "--host",
            "a",
            "--host",
            "b",
            "9391"
        },
        {
            "9391",
            "return 1",
            "extra"
        },
        {
            "--watch",
            "x",
            "9391",
            "return 1"
        },
        {
            "--host"
        }
    }) do
        test.assert_eq(console_cli.parse(args), nil, table.concat(args, " "))
    end
end)

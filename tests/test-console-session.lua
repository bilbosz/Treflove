local test = require("tests.lib.test")
local ConsoleClient = require("utils.console-client")
local ConsoleSession = require("utils.console-session")
local console_socket = require("tests.lib.console-socket")

local frame = console_socket.frame

---@class TestSessionWorld
---@field socket TestFakeSocket
---@field lines string[] Every output line, `err: ` before an error's

---@param mode ConsoleSessionMode
---@return ConsoleSession, TestSessionWorld
local function open(mode)
    ---@type TestSessionWorld
    local world = {
        socket = console_socket.make(),
        lines = {}
    }
    local session = ConsoleSession("127.0.0.1", "9391", mode, function(line, is_error)
        table.insert(world.lines, (is_error and "err: " or "") .. line)
    end, function()
        return world.socket
    end)
    return session, world
end

---@param session ConsoleSession
---@param n integer
local function step(session, n)
    for i = 1, n do
        test.assert_true(session:step(0), "finished at step " .. i)
    end
end

test.suite("ConsoleSession")

test.case("connects to the address and port given, and a refused connection raises", function()
    local _, world = open({
        chunk = "return 1",
        follow = false
    })
    test.assert_eq(world.socket.address, "127.0.0.1")
    test.assert_eq(world.socket.port, 9391)
    local refusing = console_socket.make()
    refusing.refuse = true
    test.assert_error(function()
        ConsoleSession("localhost", "9391", {
            chunk = "return 1",
            follow = false
        }, function()
        end, function()
            return refusing
        end)
    end)
    test.assert_error(function()
        open({
            follow = false
        })
    end, "neither a chunk nor a watch")
end)

test.case("one shot: the ok reply is output and finishes with 0, closing the connection", function()
    local session, world = open({
        chunk = "return 1 + 1",
        follow = false
    })
    session:start()
    test.assert_eq(world.socket.sent, frame("eval", "return 1 + 1"))
    step(session, 2)
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_FAILURE, "no reply yet")
    world.socket.arriving = {
        frame("log", "not followed") .. frame("ok", "2")
    }
    test.assert_false(session:step(0))
    test.assert_deep_eq(world.lines, {
        "2"
    })
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_OK)
    test.assert_true(world.socket.closed)
    test.assert_false(session:step(0), "finished stays finished")
end)

test.case("one shot: an empty ok body outputs nothing", function()
    local session, world = open({
        chunk = "pause()",
        follow = false
    })
    session:start()
    world.socket.arriving = {
        frame("ok", "")
    }
    test.assert_false(session:step(0))
    test.assert_deep_eq(world.lines, {})
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_OK)
end)

test.case("an error reply goes to the error output and finishes with 1, following or not", function()
    for _, follow in ipairs({
        false,
        true
    }) do
        local session, world = open({
            chunk = "error('x')",
            follow = follow
        })
        session:start()
        world.socket.arriving = {
            frame("error", "console:1: x\nstack traceback:\n\t[C]: in function 'error'")
        }
        test.assert_false(session:step(0))
        test.assert_deep_eq(world.lines, {
            "err: console:1: x\nstack traceback:\n\t[C]: in function 'error'"
        })
        test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_ERROR)
        test.assert_true(world.socket.closed)
    end
end)

test.case("following: the frames before and after the reply are output in order, until the connection closes with 0", function()
    local session, world = open({
        chunk = "log(true)",
        follow = true
    })
    session:start()
    world.socket.arriving = {
        frame("log", "before") .. frame("ok", "") .. frame("watch", "hp\t3\t0.05\t10")
    }
    step(session, 1)
    world.socket.arriving = {
        frame("log", "after")
    }
    step(session, 1)
    test.assert_deep_eq(world.lines, {
        "before",
        "hp\t3\t0.05\t10",
        "after"
    })
    world.socket.peer_closed = true
    test.assert_false(session:step(0))
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_OK)
end)

test.case("watch mode sends the watch chunk of the expression and follows", function()
    local session, world = open({
        follow = false,
        watch = "app:get_time()"
    })
    session:start()
    test.assert_eq(world.socket.sent, frame("eval", ConsoleSession.watch_chunk("app:get_time()")))
    world.socket.arriving = {
        frame("ok", ""),
        frame("watch", "app:get_time()\t60\t1\t1")
    }
    step(session, 2)
    test.assert_deep_eq(world.lines, {
        "app:get_time()\t60\t1\t1"
    })
end)

test.case("the connection closing before the reply goes to the error output and finishes with 2", function()
    local session, world = open({
        chunk = "quit()",
        follow = true
    })
    session:start()
    world.socket.peer_closed = true
    test.assert_false(session:step(0))
    test.assert_deep_eq(world.lines, {
        "err: the console connection closed"
    })
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_FAILURE)
end)

test.case("a reply that does not come in time goes to the error output and finishes with 2", function()
    local default_timeout = ConsoleClient.DEFAULT_TIMEOUT
    ConsoleClient.DEFAULT_TIMEOUT = 0
    ---@type boolean, any
    local ok, err = pcall(function()
        local session, world = open({
            chunk = "return 1",
            follow = false
        })
        session:start()
        test.assert_false(session:step(0))
        test.assert_deep_eq(world.lines, {
            "err: the console request timed out"
        })
        test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_FAILURE)
        test.assert_true(world.socket.closed)
    end)
    ConsoleClient.DEFAULT_TIMEOUT = default_timeout
    if not ok then
        error(err, 0)
    end
end)

test.case("a send that fails finishes at the start with 2", function()
    local session, world = open({
        chunk = "return 1",
        follow = false
    })
    session:close()
    session:start()
    test.assert_false(session:step(0))
    test.assert_deep_eq(world.lines, {
        "err: the console connection closed"
    })
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_FAILURE)
end)

test.case("a malformed frame finishes with 2", function()
    local session, world = open({
        chunk = "return 1",
        follow = true
    })
    session:start()
    world.socket.arriving = {
        frame("ok", "1") .. "garbage\n"
    }
    test.assert_false(session:step(0))
    test.assert_eq(world.lines[1], "1")
    test.assert_eq(#world.lines, 2)
    test.assert_eq(session:get_exit_code(), ConsoleSession.EXIT_FAILURE)
end)

test.case("a step waits at most its timeout and a session steps only once started", function()
    local session = open({
        chunk = "return 1",
        follow = false
    })
    test.assert_error(function()
        session:step(0)
    end, "not started")
    session:start()
    test.assert_error(function()
        session:start()
    end, "started twice")
    local before = os.clock()
    test.assert_true(session:step(0.03))
    test.assert_true(os.clock() - before < 1)
end)

test.suite("ConsoleSession.parse")

test.case("takes the port and the chunk, the chunk from stdin without one or for -", function()
    test.assert_deep_eq(ConsoleSession.parse({
        "9391",
        "return 1"
    }), {
        port = "9391",
        chunk = "return 1",
        follow = false
    })
    test.assert_deep_eq(ConsoleSession.parse({
        "9391"
    }), {
        port = "9391",
        follow = false
    })
    test.assert_deep_eq(ConsoleSession.parse({
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
        test.assert_deep_eq(ConsoleSession.parse(args), expected, table.concat(args, " "))
    end
end)

test.case("takes watch before or after the port", function()
    local before = assert(ConsoleSession.parse({
        "--watch",
        "app:get_time()",
        "9391"
    }))
    local after = assert(ConsoleSession.parse({
        "9391",
        "--watch",
        "app:get_time()"
    }))
    test.assert_deep_eq(after, before)
end)

test.case("takes watch as the expression, without a chunk", function()
    test.assert_deep_eq(ConsoleSession.parse({
        "--watch",
        "app:get_time()",
        "9391"
    }), {
        port = "9391",
        follow = false,
        watch = "app:get_time()"
    })
end)

test.case("the watch chunk watches the expression under its own text", function()
    ---@type string, fun(): any
    local name, fn
    local chunk = assert(loadstring(ConsoleSession.watch_chunk("app:get_time()")))
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
        test.assert_eq(ConsoleSession.parse(args), nil, table.concat(args, " "))
    end
end)

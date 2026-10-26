local test = require("tests.lib.test")
local ConsoleClient = require("utils.console-client")
local console_socket = require("tests.lib.console-socket")

local make_socket, frame = console_socket.make, console_socket.frame

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

test.case("two async requests in flight are completed in order by poll, the frames between them handled", function()
    local fake = make_socket()
    local client = connect(fake)
    ---@type string[]
    local handled = {}
    client:set_frame_handler(function(kind, body)
        table.insert(handled, kind .. " " .. body)
    end)
    local first = client:request_async("return 1")
    local second = client:request_async("error('two')")
    test.assert_eq(fake.sent, "eval 8\nreturn 1eval 12\nerror('two')")
    test.assert_false(first:is_done())
    test.assert_error(function()
        first:get_result()
    end, "no reply yet")
    test.assert_true(client:poll())
    test.assert_false(first:is_done(), "nothing arrived")
    fake.arriving = {
        frame("ok", "1") .. frame("log", "between") .. "error 3\nt"
    }
    test.assert_true(client:poll())
    test.assert_true(first:is_done())
    test.assert_false(second:is_done(), "its reply is not whole")
    test.assert_deep_eq({
        first:get_result()
    }, {
        true,
        "1"
    })
    fake.arriving = {
        "wo"
    }
    client:poll()
    test.assert_true(second:is_done())
    test.assert_deep_eq({
        second:get_result()
    }, {
        false,
        "two"
    })
    test.assert_deep_eq(handled, {
        "log between"
    })
end)

test.case("a request waits behind the async requests sent before it, its reply the one after theirs", function()
    local fake = make_socket()
    local client = connect(fake)
    local async = client:request_async("return 'a'")
    fake.arriving = {
        frame("ok", "a"),
        frame("ok", "b")
    }
    local ok, body = client:request("return 'b'")
    test.assert_true(ok)
    test.assert_eq(body, "b")
    test.assert_true(async:is_done())
    test.assert_deep_eq({
        async:get_result()
    }, {
        true,
        "a"
    })
end)

test.case("the late reply of a request that timed out completes it, not the next request", function()
    local fake = make_socket()
    local client = connect(fake)
    test.assert_error(function()
        client:request("return 'late'", 0.01)
    end)
    fake.arriving = {
        frame("ok", "late"),
        frame("ok", "next")
    }
    local _, body = client:request("return 'next'")
    test.assert_eq(body, "next")
end)

test.case("a closed connection fails every pending request, and an ok or error frame without one goes to the frame handler", function()
    local fake = make_socket()
    local client = connect(fake)
    ---@type string[]
    local handled = {}
    client:set_frame_handler(function(kind, body)
        table.insert(handled, kind .. " " .. body)
    end)
    fake.arriving = {
        frame("ok", "stray")
    }
    client:poll()
    test.assert_deep_eq(handled, {
        "ok stray"
    })
    local first = client:request_async("return 1")
    local second = client:request_async("return 2")
    fake.peer_closed = true
    test.assert_false(client:poll())
    test.assert_true(fake.closed)
    for _, request in ipairs({
        first,
        second
    }) do
        test.assert_true(request:is_done())
        local ok, err = pcall(request.get_result, request)
        test.assert_false(ok)
        test.assert_eq(err, "the console connection closed")
    end
    test.assert_error(function()
        client:request_async("return 3")
    end, "a request on a closed connection")
end)

test.case("close fails the pending requests", function()
    local fake = make_socket()
    local client = connect(fake)
    local request = client:request_async("return 1")
    client:close()
    test.assert_true(request:is_done())
    test.assert_error(function()
        request:get_result()
    end)
end)

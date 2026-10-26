---@class console_socket
local console_socket = {}

---@return TestFakeSocket
function console_socket.make()
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
function console_socket.frame(kind, body)
    return string.format("%s %d\n%s", kind, #body, body)
end

return console_socket

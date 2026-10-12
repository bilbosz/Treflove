-- The part of luasocket Treflove uses (LÖVE bundles luasocket; the test
-- runner stubs `gettime` under plain LuaJIT, tests/run.lua): the clock, and
-- the TCP sockets of the connection threads (networking/detail/*).
local record socket
    -- A connected TCP socket (luasocket's "client" object).
    interface TcpClient
        -- `pattern` is "*l" (a line) or a number of bytes; on failure the
        -- data is nil and the error is "closed", "timeout" or a message.
        receive: function(self, pattern: string | number): (string, string)
        -- The index of the last byte sent, or nil and the error.
        send: function(self, data: string): (integer, string)
        close: function(self)
    end

    -- A listening TCP socket (luasocket's "server" object).
    interface TcpServer
        accept: function(self): (TcpClient, string)
        -- The address and the port it is bound to.
        getsockname: function(self): (string, integer)
        close: function(self)
    end

    gettime: function(): number
    -- A server bound to `address`:`port` (0 for any free port), or nil and
    -- the error.
    bind: function(address: string, port: number | string): (TcpServer, string)
    -- A client connected to `address`:`port`, or nil and the error.
    connect: function(address: string, port: number | string): (TcpClient, string)
end

return socket

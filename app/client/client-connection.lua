local channel, params = ...

local socket = require("socket")

local port
do
    local client = assert(socket.connect(params.address, tonumber(params.port)))

    local error
    port, error = client:receive("*a")
    assert(not error, error)
    port = tonumber(port)
    assert(port)
    client:close()
end

do
    local client = assert(socket.connect(params.address, tonumber(port)))
    local size, error = client:receive("*l")
    assert(not error, error)
    size = tonumber(size)
    assert(size)
    local content, error = client:receive(size)
    assert(not error, error)
    channel:push(content)
end
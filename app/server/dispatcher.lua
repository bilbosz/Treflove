local mainChannel, params = ...

local socket = require("socket")

local server = assert(socket.bind(params.address, tonumber(params.port)))

while true do
    local client = server:accept()

    local dispatcherChannel = love.thread.newChannel()
    love.thread.newThread("app/server/server-connection.lua"):start(mainChannel, dispatcherChannel, params.address)

    local port = dispatcherChannel:demand()
    local error = select(2, client:send(port))
    assert(not error, error)

    client:close()
end
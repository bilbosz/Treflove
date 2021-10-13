local channel, address, port = ...

local socket = require("socket")

local server = socket.bind(address, tonumber(port))
while true do
    local client = server:accept()

    local dispatcherChannel = love.thread.newChannel()
    love.thread.newThread("networking/impl/server-in.lua"):start(address, dispatcherChannel, channel)

    local inPort = dispatcherChannel:demand()
    client:send(tostring(inPort) .. "\n")

    client:close()
end

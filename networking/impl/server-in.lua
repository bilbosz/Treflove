local address, dispatcherChannel, channel = ...

local socket = require("socket")

local inServer = socket.bind(address, 0)
local inPort = select(2, inServer:getsockname())
dispatcherChannel:push(inPort)
local inClient = inServer:accept()

local outPort = inClient:receive("*l")
local inChannel, outChannel = love.thread.newChannel(), love.thread.newChannel()
love.thread.newThread("networking/impl/server-out.lua"):start(address, inPort, outPort, inChannel, outChannel, channel)

while true do
    local msg, error = inClient:receive("*l")
    if error then
        break
    end
    local n = tonumber(msg)
    assert(type(n) == "number")
    local data, error = inClient:receive(n)
    if error then
        break
    end
    inChannel:push(data)
end
inChannel:push(false)

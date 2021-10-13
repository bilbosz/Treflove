local address, getPortChannel, inChannel = ...

local socket = require("socket")

local inServer = socket.bind(address, 0)
local inPort = select(2, inServer:getsockname())
getPortChannel:push(inPort)
local inClient = inServer:accept()

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

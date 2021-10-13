local address, inPort, outPort, inChannel, outChannel, mainChannel = ...

local socket = require("socket")

local outClient = socket.connect(address, outPort)
mainChannel:push({inChannel, outChannel})

local msg = outChannel:demand()
while msg ~= false do
    assert(type(msg) == "string")
    local n = #msg
    outClient:send(tostring(n) .. "\n")
    outClient:send(msg)
    msg = outChannel:demand()
end
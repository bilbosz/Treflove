local channel, address, port = ...

local socket = require("socket")

local outPort
do
    local client = socket.connect(address, tonumber(port))
    if not client then
        return
    end
    outPort = client:receive("*l")
    client:close()
end

do
    local getPortChannel = love.thread.newChannel()
    local inChannel, outChannel = love.thread.newChannel(), love.thread.newChannel()
    local outClient = socket.connect(address, tonumber(outPort))
    local thread = love.thread.newThread("networking/impl/client-in.lua")
    thread:start(address, getPortChannel, inChannel)

    local inPort = getPortChannel:demand()
    outClient:send(tostring(inPort) .. "\n")
    channel:push({inChannel, outChannel})

    local msg = outChannel:demand()
    while msg ~= false do
        assert(type(msg) == "string")
        local n = #msg
        outClient:send(tostring(n) .. "\n")
        outClient:send(msg)
        msg = outChannel:demand()
    end
    outClient:close()
    thread:release()
end

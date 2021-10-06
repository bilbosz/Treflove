local mainChannel, dispatcherChannel, address = ...

local socket = require("socket")

local server = assert(socket.bind(address, 0))
local port = select(2, server:getsockname())
dispatcherChannel:push(port)

local channel = love.thread.newChannel()
local client = server:accept()
mainChannel:push(channel)

local data = channel:demand()
local size = #data

client:send(tostring(size) .. "\n")
client:send(data)
Connection = {}

local function Compress(message)
    return love.data.compress("string", Consts.NETWORK_COMPRESSION, table.tostring(message))
end

local function Decompress(payload)
    return table.fromstring(love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload))
end

local function HandleResponse(self, message)
    return table.remove(self.queue, 1)(message.body)
end

local function SendResponse(self, request)
    assert_type(request, "table")
    assert_type(request.body, "table")
    assert_type(request.id, "string")

    local body = self.requestHandlers[request.id](request.body)
    assert_type(body, "table")
    local response = {
        source = request.source,
        id = request.id,
        body = body
    }
    self.outChannel:push(Compress(response))
end

function Connection:Init(inChannel, inThread, outChannel, outThread)
    self.inChannel = inChannel
    self.inThread = inThread
    self.outChannel = outChannel
    self.outThread = outThread
    self.queue = {}
    self.source = app.isClient and "c" or "s"
    self.requestHandlers = {}

    app.updateEventManager:RegisterListener(self)
end

function Connection:SendRequest(id, body, responseHandler)
    assert_type(body, "table")
    assert_type(responseHandler, "function")

    local request = {
        source = self.source,
        id = id,
        body = body
    }
    table.insert(self.queue, responseHandler)
    self.outChannel:push(Compress(request))
end

function Connection:RegisterRequestHandler(id, responseHandler)
    assert(not self.requestHandlers[id])
    self.requestHandlers[id] = responseHandler
end

function Connection:UnregisterRequestHandler(id)
    self.requestHandlers[id] = nil
end

function Connection:GetInChannel()
    return self.inChannel
end

function Connection:GetOutChannel()
    return self.outChannel
end

function Connection:OnUpdate()
    while true do
        local payload = self.inChannel:pop()
        if not payload then
            break
        end
        local message = Decompress(payload)
        if message.source == self.source then
            HandleResponse(self, message)
        else
            SendResponse(self, message)
        end
    end
end

function Connection:Release()
    app.updateEventManager:UnregisterListener(self)
    self.inThread:release()
    self.inChannel:release()
    self.outThread:release()
    self.outChannel:release()
end

MakeClassOf(Connection, UpdateEventListener)

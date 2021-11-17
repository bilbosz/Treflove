Connection = {}

local function Compress(message)
    return love.data.compress("string", Consts.NETWORK_COMPRESSION, table.tostring(message))
end

local function Decompress(load)
    return table.fromstring(love.data.decompress("string", Consts.NETWORK_COMPRESSION, load))
end

local function HandleResponse(self, message)
    return table.remove(self.queue, 1)(message.body)
end

local function SendResponse(self, request)
    assert(type(request) == "table")
    assert(type(request.body) == "table")

    local body = self.requestHandler(request.body)
    assert(type(body) == "table")
    local response = {
        source = request.source,
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

    app.updateEventManager:RegisterListener(self)
end

function Connection:Start(requestHandler)
    self.requestHandler = requestHandler
end

function Connection:SendRequest(body, responseHandler)
    assert(type(body) == "table")
    assert(type(responseHandler) == "function")

    local request = {
        source = self.source,
        body = body
    }
    table.insert(self.queue, responseHandler)
    self.outChannel:push(Compress(request))
end

function Connection:GetInChannel()
    return self.inChannel
end

function Connection:GetOutChannel()
    return self.outChannel
end

function Connection:OnUpdate()
    while true do
        local load = self.inChannel:pop()
        if not load then
            break
        end
        local message = Decompress(load)
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

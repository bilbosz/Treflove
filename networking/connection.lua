Connection = {}

function Connection:Init(inChannel, inThread, outChannel, outThread)
    UpdateObserver.Init(self)
    self.inChannel = inChannel
    self.inThread = inThread
    self.outChannel = outChannel
    self.outThread = outThread
end

function Connection:Start(requestHandler)
    self.requestHandler = requestHandler
end

function Connection:SendRequest(request, responseHandler)
    local compressed = love.data.compress("string", Consts.NETWORK_COMPRESSION, table.tostring(request))
    self.outChannel:push(compressed)
end

function Connection:GetInChannel()
    return self.inChannel
end

function Connection:GetOutChannel()
    return self.outChannel
end

function Connection:Update()
    while true do
        local msg = self.inChannel:pop()
        if not msg then
            break
        end
        msg = table.fromstring(love.data.decompress("string", Consts.NETWORK_COMPRESSION, msg))
        self.requestHandler(msg)
    end
end

function Connection:Release()
    UpdateObserver.Release(self)
    self.inThread:release()
    self.inChannel:release()
    self.outThread:release()
    self.outChannel:release()
end

MakeClassOf(Connection, UpdateObserver)

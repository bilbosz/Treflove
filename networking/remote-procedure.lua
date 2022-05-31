RemoteProcedure = {}

function RemoteProcedure:Init(connection, dontStart)
    assert(connection)
    self.connection = connection
    self.id = getmetatable(getmetatable(self).class).name

    if not dontStart then
        self:Start()
    end
end

function RemoteProcedure:Start()
    self.connection:RegisterRequestHandler(self.id, function(request)
        return self:SendResponse(request)
    end)
end

function RemoteProcedure:Stop()
    self.connection:UnregisterRequestHandler(self.id)
end

function RemoteProcedure:SendRequest(request, cb)
    self.connection:SendRequest(self.id, request, function(response)
        self:ReceiveResponse(response)
        if cb then
            cb(response)
        end
    end)
end

function RemoteProcedure:SendResponse(request)
    abstract()
end

function RemoteProcedure:ReceiveResponse(response)
    abstract()
end

function RemoteProcedure:Release()
    self:Stop()
    self.connection = nil
end

MakeClassOf(RemoteProcedure)

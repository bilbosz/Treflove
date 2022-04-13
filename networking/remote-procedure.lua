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

function RemoteProcedure:SendRequest(request)
    self.connection:SendRequest(self.id, request, function(response)
        self:ReceiveResponse(response)
    end)
end

function RemoteProcedure:SendResponse(request)
    assert(false)
end

function RemoteProcedure:ReceiveResponse(response)
    assert(false)
end

function RemoteProcedure:Release()
    self:Stop()
    self.connection = nil
end

MakeClassOf(RemoteProcedure)

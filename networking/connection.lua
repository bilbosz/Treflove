Connection = {}

function Connection:Init(inChannel, outChannel)
    UpdateObserver.Init(self)
    self.inChannel = inChannel
    self.outChannel = outChannel
end

function Connection:Start(requestHandler)
    self.requestHandler = requestHandler
end

function Connection:SendRequest(request, responseHandler)
    self.outChannel:push(request)
end

function Connection:Update()
    while true do
        local msg = self.inChannel:pop()
        if msg == false then
            return
        elseif msg == nil then
            return
        end
        self.requestHandler(msg)
    end
end

MakeClassOf(Connection, UpdateObserver)

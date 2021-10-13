UpdateObserver = {}

local subscribedObjects = {}
setmetatable(subscribedObjects, {
    __mode = "k"
})

setmetatable(UpdateObserver, { __add = function(self, other)
    subscribedObjects[other] = true
end })

function UpdateObserver.Notify(dt)
    for obj in pairs(subscribedObjects) do
        obj:Update(dt)
    end
end

function UpdateObserver:Update(dt)
    assert(false)
end

function UpdateObserver:Init()
    subscribedObjects[self] = true
end

MakeClassOf(UpdateObserver)

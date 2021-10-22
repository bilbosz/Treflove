UpdateObserver = {}

local subscribedObjects = {}
setmetatable(subscribedObjects, {
    __mode = "k"
})

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

function UpdateObserver:Release()
    subscribedObjects[self] = nil
end

MakeClassOf(UpdateObserver)

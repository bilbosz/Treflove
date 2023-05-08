FileSystemDropEventListener = {}

function FileSystemDropEventListener:Init(receiveThrough)
    self.receiveThrough = receiveThrough
end

function FileSystemDropEventListener:OnFileSystemDrop(x, y, file)
    
end

MakeClassOf(FileSystemDropEventListener, Control)

FileSystemDropEventManager = {}

local function GetListenerList(ctrl, listeners, x, y, list)
    if not ctrl:IsVisible() or not ctrl:GetGlobalRecursiveAabb():IsPointInside(x, y) then
        return nil
    end
    if listeners[ctrl] then
        table.insert(list, ctrl)
    end
    for _, child in ipairs(ctrl:GetChildren()) do
        GetListenerList(child, listeners, x, y, list)
    end
end

function FileSystemDropEventManager:Init()
    EventManager.Init(self, FileSystemDropEventListener)
end

function FileSystemDropEventManager:FileDrop(file)
    local x, y = app.pointerEventManager:GetPosition()
    self:InvokeEvent(FileSystemDropEventListener.OnFileSystemDrop, x, y, file)
end

function FileSystemDropEventManager:InvokeEvent(method, x, y, file)
    local listeners = self.methods[method]
    local list = {}
    GetListenerList(app.root, listeners, x, y, list)
    local topToBeCalled = true
    for _, ctrl in ripairs(list) do
        local listener = listeners[ctrl]
        if topToBeCalled then
            local passThrough = listener(ctrl, x, y, file)
            if not passThrough then
                topToBeCalled = false
            end
        elseif ctrl.receiveThrough then
            listener(ctrl, x, y, file)
        end
    end
end

MakeClassOf(FileSystemDropEventManager, EventManager)

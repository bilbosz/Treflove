FileDropEventListener = {}

function FileDropEventListener:Init(receiveThrough)
    self.receiveThrough = receiveThrough
end

function FileDropEventListener:OnFileDrop(x, y, path, isDir)

end

MakeClassOf(FileDropEventListener, Control)

FileDropEventManager = {}

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

function FileDropEventManager:Init()
    EventManager.Init(self, FileDropEventListener)
end

function FileDropEventManager:FileDrop(x, y, path)
    self:InvokeEvent(FileDropEventListener.OnFileDrop, x, y, path, false)
end

function FileDropEventManager:DirectoryDrop(x, y, path)
    self:InvokeEvent(FileDropEventListener.OnFileDrop, x, y, path, true)
end

function FileDropEventManager:InvokeEvent(method, x, y, path, isDir)
    local listeners = self.methods[method]
    local list = {}
    GetListenerList(app.root, listeners, x, y, list)
    local topToBeCalled = true
    for _, ctrl in ripairs(list) do
        local listener = listeners[ctrl]
        if topToBeCalled then
            local passThrough = listener(ctrl, x, y, path, isDir)
            if not passThrough then
                topToBeCalled = false
            end
        elseif ctrl.receiveThrough then
            listener(ctrl, x, y, path, isDir)
        end
    end
end

MakeClassOf(FileDropEventManager, EventManager)

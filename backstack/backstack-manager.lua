BackstackManager = {}

function BackstackManager:Init()
    self.stack = {}
    app.keyboardManager:RegisterListener(self)
end

function BackstackManager:Push(cb)
    assert(type(cb) == "function")
    table.insert(self.stack, cb)
end

function BackstackManager:Pop(cb)
    assert(cb)
    if cb == self:GetTop() then
        table.remove(self.stack)
    end
end

function BackstackManager:GetTop()
    return self.stack[#self.stack]
end

function BackstackManager:Back()
    local top = self:GetTop()
    if top then
        table.remove(self.stack)
        top()
    end
end

function BackstackManager:OnKeyPressed(key)
    if key == "escape" then
        self:Back()
    end
end

MakeClassOf(BackstackManager, KeyboardEventListener)

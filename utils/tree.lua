Tree = {}

function Tree:Init(parent)
    self.children = {}
    self.parent = nil
    if parent then
        self:SetParent(parent)
    end
end

function Tree:SetParent(parent)
    if parent then
        parent:AddChild(self)
    else
        if self.parent then
            self.parent:RemoveChild(self)
        end
    end
end

function Tree:AddChild(child)
    if child.parent then
        child.parent:RemoveChild(child)
    end
    child.parent = self
    table.insert(self.children, child)
end

function Tree:RemoveChild(child)
    local found
    for i, v in ipairs(self.children) do
        if v == child then
            found = i
            break
        end
    end
    if found then
        table.remove(self.children, found)
        child.parent = nil
    else
        assert(false)
    end
end

function Tree:GetChildren()
    return table.copy(self.children)
end

function Tree:GetParent()
    return self.parent
end

function Tree:Reattach(n)
    local children = self.parent.children
    n = n or #children
    if children[n] == self then
        return
    end
    local found
    for i, v in ipairs(children) do
        if v == self then
            found = i
            break
        end
    end
    if found then
        table.remove(children, found)
        table.insert(children, n, self)
    else
        assert(false)
    end
end

MakeClassOf(Tree)

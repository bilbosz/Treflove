local lifetime = require("lifetime")

---@class Tree: Object
---@field public parent Tree|nil
---@field public children Tree[]
local Tree = class("Tree")

---@param parent Tree|nil
function Tree:init(parent)
    self.children = {}
    self.parent = nil
    if parent then
        self:set_parent(parent)
    end
end

---@param parent Tree|nil
function Tree:set_parent(parent)
    if parent then
        parent:add_child(self)
    else
        if self.parent then
            self.parent:remove_child(self)
        end
    end
end

---@param child Tree
function Tree:add_child(child)
    if child.parent then
        child.parent:remove_child(child)
    end
    child.parent = self
    table.insert(self.children, child)
end

---@param child Tree
function Tree:remove_child(child)
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
        assert_unreachable()
    end
end

---lua-lifetime: a destroyed node leaves its parent's children while it is
---dying and still findable by identity, so no tombstone stays in the array
---(lib/lua-lifetime/docs/02-semantics.md, "Tombstones"). A parent that died
---first (a panel, before an input of its that the collector finds later) has no
---children left to leave: a tombstone is empty and raises when indexed. A
---subclass with a `release` of its own chains it:
---`Control.release(self, reason)`.
---@param reason lifetime.Reason
function Tree:release(reason)
    local parent = self.parent
    if parent and lifetime.alive(parent) then
        parent:remove_child(self)
    end
end

---@return Tree[]
function Tree:get_children()
    return table.copy(self.children)
end

---@return Tree|nil
function Tree:get_parent()
    return self.parent
end

---@param n number|nil
function Tree:reattach(n)
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
        assert_unreachable()
    end
end

return Tree

---@class DeferManager
local DeferManager = class("DeferManager")

local function AddDefers(self)
    table.merge_array(self.queue, self.to_add_defers)
    self.to_add_defers = {}
    table.sort(self.queue, function(a, b)
        return a[1] < b[1]
    end)
end

function DeferManager:init()
    self.queue = {}
    self.to_add_defers = {}
end

function DeferManager:call_defered(t, f, ...)
    assert_type(t, "number")
    assert_type(f, "function")
    table.insert(self.to_add_defers, {
        app:get_time() + t,
        f,
        {
            ...
        }
    })
end

function DeferManager:update()
    if #self.to_add_defers > 0 then
        AddDefers(self)
    end
    while #self.queue > 0 and app:get_time() >= self.queue[1][1] do
        local defer = table.remove(self.queue, 1)
        defer[2](unpack(defer[3]))
    end
end

return DeferManager

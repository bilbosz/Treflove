DeferManager = {}

local function AddDefers(self)
    table.mergearray(self.queue, self.toAddDefers)
    self.toAddDefers = {}
    table.sort(self.queue, function(a, b)
        return a[1] < b[1]
    end)
end

function DeferManager:Init()
    self.queue = {}
    self.toAddDefers = {}
end

function DeferManager:CallDefered(t, f, ...)
    table.insert(self.toAddDefers, {
        app.time + t,
        f,
        {
            ...
        }
    })
end

function DeferManager:Update()
    if #self.toAddDefers > 0 then
        AddDefers(self)
    end
    while #self.queue > 0 and app.time >= self.queue[1][1] do
        local defer = table.remove(self.queue, 1)
        defer[2](unpack(defer[3]))
    end
end

MakeClassOf(DeferManager)

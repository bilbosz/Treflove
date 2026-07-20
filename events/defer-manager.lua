---@alias DeferEntry {[1]: number, [2]: function, [3]: any[]} Invocation time, callback and its arguments
---@class DeferManager
---@field _queue DeferEntry[] Pending defers sorted by invocation time
---@field _to_add_defers DeferEntry[] Defers queued since the last update
local DeferManager = class("DeferManager")

---@param self DeferManager
local function _add_defers(self)
    table.merge_array(self._queue, self._to_add_defers)
    self._to_add_defers = {}
    table.sort(self._queue, function(a, b)
        return a[1] < b[1]
    end)
end

function DeferManager:init()
    self._queue = {}
    self._to_add_defers = {}
end

---@param t number Delay in seconds
---@param f function Callback to invoke after the delay
---@param ... any Arguments passed to the callback
function DeferManager:call_defered(t, f, ...)
    assert_type(t, "number")
    assert_type(f, "function")
    table.insert(self._to_add_defers, {
        app:get_time() + t,
        f,
        {
            ...
        }
    })
end

function DeferManager:update()
    if #self._to_add_defers > 0 then
        _add_defers(self)
    end
    while #self._queue > 0 and app:get_time() >= self._queue[1][1] do
        local defer = table.remove(self._queue, 1)
        defer[2](unpack(defer[3]))
    end
end

return DeferManager

-- events/defer-manager.tlt
-- any: a deferred callback takes the arguments it was deferred with.
global type DeferCallback = function(...: any)

-- Invocation time, callback and its arguments.
global record DeferEntry
    time: number
    callback: DeferCallback
    args: {any} -- any: see DeferCallback
end

global interface DeferManager is Object
    _queue: {DeferEntry} -- pending defers sorted by invocation time
    _to_add_defers: {DeferEntry} -- defers queued since the last update
    -- any: the arguments passed to the callback (see DeferCallback).
    call_defered: function(self, t: number, f: DeferCallback, ...: any)
    update: function(self)
end

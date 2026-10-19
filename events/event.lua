---@alias EventHandler fun(owner: table, ...: any)
---A single broadcast event. Owners register a handler that is called as
---`handler(owner, ...)` whenever the event is triggered. Instances are owned
---by managers (or by `app` directly) - consumers compose them instead of
---inheriting listener classes, and pass their handler explicitly:
---`app.update_event:register(self, self.on_update)`.
---
---Owners are held as weak keys, so an owner that is garbage collected silently
---drops out without unregistering. Handlers are held strongly, so a handler
---must not be a closure that captures its own owner (that would keep the owner
---alive) - pass a method and let the owner arrive as the first argument.
---
---Registering during a trigger is deferred until the trigger finishes;
---unregistering during a trigger takes effect immediately for the rest of that
---dispatch.
---@class Event: Object
---@field private _handlers table<table, EventHandler> Active handler per owner (weak keys)
---@field private _lock boolean True while the event is being triggered
---@field private _to_add table<table, EventHandler> Registrations to apply once the lock is released (weak keys)
---@field private _to_remove table<table, boolean> Owners unregistered while the lock was held (weak keys)
local Event = class("Event")

local WEAK_KEYS = {
    __mode = "k"
}

---@return table<table, any>
local function _make_weak_table()
    return setmetatable({}, WEAK_KEYS)
end

---@private
function Event:_handle_postponed()
    assert(not self._lock)
    for owner in pairs(self._to_remove) do
        self._handlers[owner] = nil
    end
    self._to_remove = _make_weak_table()

    for owner, handler in pairs(self._to_add) do
        self._handlers[owner] = handler
    end
    self._to_add = _make_weak_table()
end

function Event:init()
    self._handlers = _make_weak_table()
    -- lock is turned on only for triggering
    self._lock = false
    -- registering is delayed
    self._to_add = _make_weak_table()
    -- unregistering is immediate
    self._to_remove = _make_weak_table()
end

---Register `handler` to be called as `handler(owner, ...)` on trigger.
---Registering the same owner again replaces its handler.
---@param owner table
---@param handler EventHandler
function Event:register(owner, handler)
    assert_type(owner, "table")
    assert_type(handler, "function")
    if self._lock then
        self._to_add[owner] = handler
        return
    end
    self._handlers[owner] = handler
end

---@param owner table
function Event:unregister(owner)
    if self._lock then
        -- also cancels a registration made earlier in the same trigger
        self._to_add[owner] = nil
        self._to_remove[owner] = true
        return
    end
    self._handlers[owner] = nil
end

---Drop all handlers and any pending registrations. (Not a destructor: an
---event has nothing to free, and `release(reason)` is lua-lifetime's name
---for one, see docs/lifetimes.md.)
function Event:clear()
    self._to_add = _make_weak_table()
    if self._lock then
        -- the running trigger skips every owner from now on; cleaned up afterwards
        for owner in pairs(self._handlers) do
            self._to_remove[owner] = true
        end
        return
    end
    self._handlers = _make_weak_table()
    self._to_remove = _make_weak_table()
end

---Call every registered handler with `owner` plus the given arguments.
---@param ... any
function Event:trigger(...)
    assert(not self._lock, "Event triggered while already being triggered")
    self._lock = true
    for owner, handler in pairs(self._handlers) do
        if not self._to_remove[owner] then
            handler(owner, ...)
        end
    end
    self._lock = false
    self:_handle_postponed()
end

---Handler registered for `owner`, or nil. Used by managers that dispatch in
---their own order (hit-tested control trees) instead of calling `trigger`.
---@param owner table
---@return EventHandler|nil
function Event:get_handler(owner)
    if self._to_remove[owner] then
        return nil
    end
    return self._handlers[owner]
end

return Event

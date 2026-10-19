local lifetime = require("lifetime")

---@alias EventHandler fun(owner: table, ...: any)
---Owners are weak keys; handlers are held strongly, so a handler must not be
---a closure capturing its owner (it would keep the owner alive): register a
---method, the owner arrives as the first argument.
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
    self._lock = false
    self._to_add = _make_weak_table()
    self._to_remove = _make_weak_table()
end

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
        self._to_add[owner] = nil
        self._to_remove[owner] = true
        return
    end
    self._handlers[owner] = nil
end

function Event:clear()
    self._to_add = _make_weak_table()
    if self._lock then
        for owner in pairs(self._handlers) do
            self._to_remove[owner] = true
        end
        return
    end
    self._handlers = _make_weak_table()
    self._to_remove = _make_weak_table()
end

---@param ... any
function Event:trigger(...)
    assert(not self._lock, "Event triggered while already being triggered")
    self._lock = true
    for owner, handler in pairs(self._handlers) do
        if not lifetime.alive(owner) then
            self._handlers[owner] = nil
        elseif not self._to_remove[owner] then
            handler(owner, ...)
        end
    end
    self._lock = false
    self:_handle_postponed()
end

---@param owner table
---@return EventHandler|nil
function Event:get_handler(owner)
    if self._to_remove[owner] or not lifetime.alive(owner) then
        return nil
    end
    return self._handlers[owner]
end

return Event

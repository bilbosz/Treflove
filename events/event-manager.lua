---@class EventManager
---@field _methods table<function, table<table, function>> Listener method lookup per interface method
---@field _listener_index table<string, function> Method table of the listener class
---@field _lock boolean True while an event is being invoked
---@field _to_add table<table, boolean> Listeners to register once the lock is released
---@field _to_remove table<table, boolean> Listeners to unregister once the lock is released
local EventManager = class("EventManager")

---@param self EventManager
---@param listener table Listener instance
local function _handle_register(self, listener)
    for method_name, class_method in pairs(self._listener_index) do
        if self._methods[class_method] then
            local listener_method = listener[method_name]
            self._methods[class_method][listener] = listener_method
        end
    end
end

---@param self EventManager
---@param listener table Listener instance
local function _handle_unregister(self, listener)
    for _, class_method in pairs(self._listener_index) do
        if self._methods[class_method] then
            self._methods[class_method][listener] = nil
        end
    end
end

---@param method_name string
---@return boolean
local function _is_listener_method_name(method_name)
    return string.sub(method_name, 1, 3) == "on_"
end

---@param listener_class table Listener class whose `on_*` methods define the events
function EventManager:init(listener_class)
    self._methods = {}
    self._listener_index = getmetatable(listener_class).__index
    local mt = {
        __mode = "k"
    }
    for method_name, method in pairs(self._listener_index) do
        if _is_listener_method_name(method_name) then
            self._methods[method] = {}
            setmetatable(self._methods[method], mt)
        end
    end
    -- lock is turned on only for invoking
    self._lock = false
    -- adding is delayed
    self._to_add = {}
    -- removing is immediate
    self._to_remove = {}
end

---@param listener table Listener instance
function EventManager:register_listener(listener)
    if self._lock then
        self._to_add[listener] = true
        return
    end
    _handle_register(self, listener)
end

---@param listener table Listener instance
function EventManager:unregister_listener(listener)
    if self._lock then
        self._to_remove[listener] = true
        return
    end
    _handle_unregister(self, listener)
end

function EventManager:handle_postponed()
    assert(not self._lock)
    for listener in pairs(self._to_remove) do
        _handle_unregister(self, listener)
    end
    self._to_remove = {}

    for listener in pairs(self._to_add) do
        _handle_register(self, listener)
    end
    self._to_add = {}
end

---@param method function Listener class method identifying the event
---@param ... any Arguments forwarded to each listener
function EventManager:invoke_event(method, ...)
    assert(not self._lock)
    self._lock = true
    for listener, listener_method in pairs(self._methods[method]) do
        if not self._to_remove[listener] then
            listener_method(listener, ...)
        end
    end
    self._lock = false
    self:handle_postponed()
end

return EventManager

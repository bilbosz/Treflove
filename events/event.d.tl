-- events/event.tlt
-- any: a handler receives the arguments its event is triggered with, which
-- differ from event to event (dt, a key, a position).
global type EventHandler = function(owner: Object, ...: any)

global interface Event is Object
    _handlers: {Object: EventHandler}
    _lock: boolean
    _to_add: {Object: EventHandler}
    _to_remove: {Object: boolean}
    _handle_postponed: function(self)
    register: function(self, owner: Object, handler: EventHandler)
    unregister: function(self, owner: Object)
    -- any: the event's own arguments (see EventHandler).
    trigger: function(self, ...: any)
    get_handler: function(self, owner: Object): EventHandler
end

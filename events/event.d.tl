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
    -- Generic in the owner, so that a method of the owner's own class is its
    -- handler as it is (`ev:register(self, self.on_update)`, no cast): the
    -- handler is only ever called with the owner it was registered with.
    -- any: the event's own arguments (see EventHandler).
    register: function<O is Object>(self, owner: O, handler: function(owner: O, ...: any))
    unregister: function(self, owner: Object)
    -- any: the event's own arguments (see EventHandler).
    trigger: function(self, ...: any)
    get_handler: function(self, owner: Object): EventHandler
end

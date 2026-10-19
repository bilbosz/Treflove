-- utils/backstack-manager.tlt
global type BackstackManagerCb = function()

-- A pushed callback. The caller anchors it (`entry @ owner`) or destroys it
-- (`lifetime.destroy(entry)`); it removes itself from the stack as it dies.
global record BackstackEntry
    cb: BackstackManagerCb
end

global interface BackstackManager is Object
    _stack: {BackstackEntry}
    push: function(self, cb: BackstackManagerCb): BackstackEntry
    get_top: function(self): BackstackEntry
    back: function(self)
    on_key_pressed: function(self, key: love.KeyConstant)
end

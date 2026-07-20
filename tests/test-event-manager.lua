local test = require("tests.lib.test")
local EventManager = require("events.event-manager")

-- A listener interface for the tests; only `on_`-prefixed methods are events.
local PingListener = class("TestPingListener")

function PingListener:init()
    self.received = {}
end

---@param value any
function PingListener:on_ping(value)
    table.insert(self.received, value)
end

test.suite("EventManager")

test.case("registered listeners receive invoked events", function()
    local manager = EventManager(PingListener)
    local first, second = PingListener(), PingListener()
    manager:register_listener(first)
    manager:register_listener(second)

    manager:invoke_event(PingListener.on_ping, 42)

    test.assert_deep_eq(first.received, {
        42
    })
    test.assert_deep_eq(second.received, {
        42
    })
end)

test.case("unregistered listeners stop receiving events", function()
    local manager = EventManager(PingListener)
    local listener = PingListener()
    manager:register_listener(listener)
    manager:invoke_event(PingListener.on_ping, 1)
    manager:unregister_listener(listener)
    manager:invoke_event(PingListener.on_ping, 2)

    test.assert_deep_eq(listener.received, {
        1
    })
end)

test.case("a listener can unregister itself during dispatch", function()
    local manager = EventManager(PingListener)
    local listener = PingListener()

    -- Override on the instance: captured at registration time.
    function listener:on_ping(value)
        table.insert(self.received, value)
        manager:unregister_listener(self)
    end

    manager:register_listener(listener)
    manager:invoke_event(PingListener.on_ping, "first")
    manager:invoke_event(PingListener.on_ping, "second")

    test.assert_deep_eq(listener.received, {
        "first"
    })
end)

test.case("a listener registered during dispatch is active from the next invoke", function()
    local manager = EventManager(PingListener)
    local late = PingListener()
    local trigger = PingListener()

    function trigger:on_ping(value)
        table.insert(self.received, value)
        manager:register_listener(late)
    end

    manager:register_listener(trigger)
    manager:invoke_event(PingListener.on_ping, "first")
    test.assert_deep_eq(late.received, {}, "not called during the invoke that registered it")

    manager:invoke_event(PingListener.on_ping, "second")
    test.assert_deep_eq(late.received, {
        "second"
    })
end)

test.case("the dispatch lock is released after every invoke", function()
    local manager = EventManager(PingListener)
    local listener = PingListener()
    manager:register_listener(listener)
    manager:invoke_event(PingListener.on_ping, 1)
    manager:invoke_event(PingListener.on_ping, 2)
    test.assert_deep_eq(listener.received, {
        1,
        2
    })
end)

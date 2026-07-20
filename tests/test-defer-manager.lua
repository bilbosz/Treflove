local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local DeferManager = require("events.defer-manager")

test.suite("DeferManager")

test.case("a defer fires only once its time has come", function()
    local app_mock = mocks.install_app()
    local manager = DeferManager()
    local calls = {}
    manager:call_defered(1, function(value)
        table.insert(calls, value)
    end, "payload")

    manager:update()
    test.assert_deep_eq(calls, {}, "not yet due")

    app_mock:advance_time(0.5)
    manager:update()
    test.assert_deep_eq(calls, {}, "still not due")

    app_mock:advance_time(0.6)
    manager:update()
    test.assert_deep_eq(calls, {
        "payload"
    })

    manager:update()
    test.assert_deep_eq(calls, {
        "payload"
    }, "fires exactly once")
end)

test.case("defers fire ordered by their due time, not insertion order", function()
    local app_mock = mocks.install_app()
    local manager = DeferManager()
    local order = {}
    manager:call_defered(2, function()
        table.insert(order, "late")
    end)
    manager:call_defered(1, function()
        table.insert(order, "early")
    end)

    app_mock:advance_time(3)
    manager:update()
    test.assert_deep_eq(order, {
        "early",
        "late"
    })
end)

test.case("varargs are forwarded to the callback", function()
    mocks.install_app()
    local manager = DeferManager()
    local received
    manager:call_defered(0, function(...)
        received = {
            ...
        }
    end, 1, "two", true)

    manager:update()
    test.assert_deep_eq(received, {
        1,
        "two",
        true
    })
end)

test.case("a defer scheduled from a callback runs on a later update", function()
    local app_mock = mocks.install_app()
    local manager = DeferManager()
    local calls = {}
    manager:call_defered(0, function()
        table.insert(calls, "outer")
        manager:call_defered(0, function()
            table.insert(calls, "inner")
        end)
    end)

    app_mock:advance_time(1)
    manager:update()
    test.assert_deep_eq(calls, {
        "outer"
    }, "the nested defer is buffered")

    manager:update()
    test.assert_deep_eq(calls, {
        "outer",
        "inner"
    })
end)

test.case("call_defered validates its arguments", function()
    mocks.install_app()
    local manager = DeferManager()
    test.assert_error(function()
        manager:call_defered("soon", function()
        end)
    end)
    test.assert_error(function()
        manager:call_defered(1, "not a function")
    end)
end)

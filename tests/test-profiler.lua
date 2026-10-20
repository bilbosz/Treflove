local test = require("tests.lib.test")
local profiler = require("utils.profiler")

test.suite("profiler")

test.case("is off until started, and every call is a no-op", function()
    test.assert_false(profiler.enabled)
    test.assert_eq(profiler.zone_begin("update"), nil)
    test.assert_eq(profiler.zone_begin_of({}), nil, "the class of the object is not looked up")
    profiler.zone_end(nil)
    profiler.zone_text(nil, "text")
    profiler.zone_value(nil, 1)
    profiler.frame_mark()
    profiler.plot("Lua heap (KB)", collectgarbage("count"))
    test.assert_false(profiler.is_connected())
end)

test.case("wrap leaves the function as it is while off", function()
    local function f()
        return 1
    end
    local t = {
        f = f
    }
    profiler.wrap(t, "f", "f")
    test.assert_eq(t.f, f)
end)

test.case("start without the environment variable stays off", function()
    local enabled, reason = profiler.start("")
    test.assert_false(enabled)
    test.assert_eq(reason, profiler.ENV_VAR .. " is not set")
    test.assert_false(profiler.enabled)
end)

test.case("start with a library that cannot be loaded stays off", function()
    local enabled, reason = profiler.start("/nonexistent/libTracyClient.so")
    test.assert_false(enabled)
    test.assert_eq(type(reason), "string")
    test.assert_false(profiler.enabled)
    test.assert_eq(profiler.zone_begin("update"), nil)
end)

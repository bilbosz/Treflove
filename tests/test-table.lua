local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")

test.suite("table utilities")

test.case("merge overwrites destination keys with source keys", function()
    local destination = {
        a = 1,
        b = 2
    }
    table.merge(destination, {
        b = 20,
        c = 30
    })
    test.assert_deep_eq(destination, {
        a = 1,
        b = 20,
        c = 30
    })
end)

test.case("merge_array appends preserving order", function()
    local destination = {
        1,
        2
    }
    table.merge_array(destination, {
        3,
        4
    })
    test.assert_deep_eq(destination, {
        1,
        2,
        3,
        4
    })
end)

test.case("copy is shallow, deep_copy is recursive", function()
    local source = {
        nested = {
            value = 1
        }
    }
    local shallow = table.copy(source)
    local deep = table.deep_copy(source)
    test.assert_eq(shallow.nested, source.nested, "shallow copy shares nested tables")
    test.assert_true(deep.nested ~= source.nested, "deep copy duplicates nested tables")
    test.assert_deep_eq(deep, source)
end)

test.case("find_table_key and find_array_idx locate values", function()
    test.assert_eq(table.find_table_key({
        a = "x",
        b = "y"
    }, "y"), "b")
    test.assert_eq(table.find_table_key({}, "missing"), nil)
    test.assert_eq(table.find_array_idx({
        "x",
        "y"
    }, "y"), 2)
    test.assert_eq(table.find_array_idx({
        "x"
    }, "missing"), nil)
end)

test.case("copy, deep_copy, merge, is_empty and cpairs skip lua-lifetime's state record", function()
    local lifetime = require("lifetime")
    local anchored = lifetime.attach({
        a = 1,
        nested = {
            b = 2
        }
    }, lifetime.reachable)
    local keys = 0
    for _ in pairs(anchored) do
        keys = keys + 1
    end
    test.assert_eq(keys, 3, "pairs shows the runtime's record")

    test.assert_deep_eq(table.copy(anchored), {
        a = 1,
        nested = anchored.nested
    })
    test.assert_deep_eq(table.deep_copy(anchored), {
        a = 1,
        nested = {
            b = 2
        }
    })
    local merged = {}
    table.merge(merged, anchored)
    test.assert_deep_eq(merged, {
        a = 1,
        nested = anchored.nested
    })
    local seen = 0
    for _ in cpairs(anchored) do
        seen = seen + 1
    end
    test.assert_eq(seen, 2)
    test.assert_false(table.is_empty(anchored))
    test.assert_true(table.is_empty(lifetime.attach({}, lifetime.reachable)))
end)

test.case("is_empty and is_identifier", function()
    test.assert_true(table.is_empty({}))
    test.assert_false(table.is_empty({
        1
    }))
    test.assert_true(table.is_identifier("valid_name2"))
    test.assert_false(table.is_identifier("2starts_with_digit"))
    test.assert_false(table.is_identifier("has space"))
end)

test.case("to_string/from_string round-trips quotes, backslashes and line breaks, one line per string", function()
    local original = {
        quoted = "say \"hi\"",
        slashed = "a\\b",
        multiline = "line1\nline2",
        both = "\"\\\n\""
    }
    local serialized = table.to_string(original)
    test.assert_true(string.find(serialized, "say \\\"hi\\\"", 1, true) ~= nil, serialized)
    test.assert_eq(select(2, string.gsub(serialized, "\n", "")), 5, "one line per field, no raw line break inside a string")
    test.assert_deep_eq(table.from_string(serialized), original)
end)

test.case("to_string/from_string round-trips nested tables", function()
    local original = {
        1,
        2,
        3,
        name = "page",
        size = {
            width = 10,
            height = 20
        },
        flags = {
            true,
            false
        },
        multiline = "line1\nline2"
    }
    local restored = table.from_string(table.to_string(original))
    test.assert_deep_eq(restored, original)
end)

test.case("from_string logs and returns nil for invalid input", function()
    local app_mock = mocks.install_app()
    test.assert_eq(table.from_string("this is not lua"), nil)
    test.assert_true(#app_mock.logs > 0, "the failure is logged")
end)

test.case("ripairs iterates backwards", function()
    local visited = {}
    for i, v in ripairs({
        "a",
        "b",
        "c"
    }) do
        table.insert(visited, {
            i,
            v
        })
    end
    test.assert_deep_eq(visited, {
        {
            3,
            "c"
        },
        {
            2,
            "b"
        },
        {
            1,
            "a"
        }
    })
end)

test.case("cipairs iterates a copy, so removal during iteration is safe", function()
    local t = {
        "a",
        "b",
        "c"
    }
    local visited = {}
    for _, v in cipairs(t) do
        table.insert(visited, v)
        t[#t] = nil
    end
    test.assert_deep_eq(visited, {
        "a",
        "b",
        "c"
    })
end)

test.case("prev steps backwards and terminates", function()
    local t = {
        "a",
        "b"
    }
    local i, v = prev(t, 2)
    test.assert_eq(i, 1)
    test.assert_eq(v, "a")
    test.assert_eq(prev(t, 1), nil)
end)

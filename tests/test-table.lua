local mocks = require("tests.lib.mocks")
local test = require("tests.lib.test")
local table_utils = require("utils.table")

test.suite("table utilities")

test.case("merge overwrites destination keys with source keys", function()
    local destination = {
        a = 1,
        b = 2
    }
    table_utils.merge(destination, {
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
    table_utils.merge_array(destination, {
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
    local shallow = table_utils.copy(source)
    local deep = table_utils.deep_copy(source)
    test.assert_eq(shallow.nested, source.nested, "shallow copy shares nested tables")
    test.assert_true(deep.nested ~= source.nested, "deep copy duplicates nested tables")
    test.assert_deep_eq(deep, source)
end)

test.case("find_table_key and find_array_idx locate values", function()
    test.assert_eq(table_utils.find_table_key({
        a = "x",
        b = "y"
    }, "y"), "b")
    test.assert_eq(table_utils.find_table_key({}, "missing"), nil)
    test.assert_eq(table_utils.find_array_idx({
        "x",
        "y"
    }, "y"), 2)
    test.assert_eq(table_utils.find_array_idx({
        "x"
    }, "missing"), nil)
end)

test.case("is_empty and is_identifier", function()
    test.assert_true(table_utils.is_empty({}))
    test.assert_false(table_utils.is_empty({
        1
    }))
    test.assert_true(table_utils.is_identifier("valid_name2"))
    test.assert_false(table_utils.is_identifier("2starts_with_digit"))
    test.assert_false(table_utils.is_identifier("has space"))
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
    local restored = table_utils.from_string(table_utils.to_string(original))
    test.assert_deep_eq(restored, original)
end)

test.case("from_string logs and returns nil for invalid input", function()
    local app_mock = mocks.install_app()
    test.assert_eq(table_utils.from_string("this is not lua"), nil)
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

test.case("a table the lifetime runtime has seen: its state record is skipped", function()
    local lifetime = require("lifetime")
    local owner = lifetime.token("owner")
    local seen = lifetime.attach({}, false, owner)
    local state_key = next(seen)
    test.assert_true(lifetime.is_state(state_key), "the runtime keeps a state record in the table")
    test.assert_true(table_utils.is_empty(seen), "is_empty")
    test.assert_eq(next(table_utils.copy(seen)), nil, "copy")
    test.assert_eq(next(table_utils.deep_copy({
        inner = seen
    }).inner), nil, "deep_copy")
    local visited = 0
    for _ in cpairs(seen) do
        visited = visited + 1
    end
    test.assert_eq(visited, 0, "cpairs")

    seen.value = 1
    local target = lifetime.attach({}, false, owner)
    local target_state = next(target)
    local target_record = rawget(target, target_state)
    table_utils.merge(target, seen)
    test.assert_eq(target.value, 1)
    test.assert_eq(rawget(target, target_state), target_record, "merge keeps the target's own record")
    local keys = 0
    for k in pairs(target) do
        if lifetime.is_state(k) then
            keys = keys + 1
        end
    end
    test.assert_eq(keys, 1, "merge copies no second record")
    test.assert_eq(table_utils.from_string(table_utils.to_string(seen)).value, 1, "to_string writes no record")
    lifetime.destroy(owner)
end)

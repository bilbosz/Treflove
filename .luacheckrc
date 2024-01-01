-- https://luacheck.readthedocs.io/en/stable/index.html
max_line_length = false
max_comment_line_length = false

std = {
    read_globals = {
        "arg",
        "assert",
        "collectgarbage",
        "debug",
        "getmetatable",
        "ipairs",
        "loadstring",
        "math",
        "next",
        "pairs",
        "pcall",
        "print",
        "require",
        "select",
        "setmetatable",
        "string",
        "tonumber",
        "tostring",
        "type",
        "unpack",
        "xpcall",
    },

    globals = {
        "abstract",
        "app",
        "assert_type",
        "assert_unreachable",
        "cipairs",
        "class",
        "config",
        "cpairs",
        "cripairs",
        "draw_aabbs",
        "dump",
        "get_class_name_of",
        "get_class_of",
        "get_stack_trace",
        "get_time",
        "is_instance_of",
        "love",
        "prev",
        "ripairs",
        "table",
        "toboolean",
    }
}

exclude_files = {
    "doc/**"
}

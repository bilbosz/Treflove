-- https://luacheck.readthedocs.io/en/stable/index.html
max_line_length = false
max_comment_line_length = false

-- 212 (unused argument): listener interfaces and callback tables keep their
-- full parameter lists as API documentation even when a stub body ignores them
ignore = {"212"}

std = {
    read_globals = {
        "_G",
        "arg",
        "assert",
        "collectgarbage",
        "debug",
        "error",
        "getmetatable",
        "io",
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
    "doc/**",
    -- lua-language-server plugin, runs inside the language server's own
    -- environment (parser.guide, cli.visualize), not inside the app
    ".vscode/**"
}

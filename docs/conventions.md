# Code Conventions

- **Naming**:
  - snake_case for functions, variables, and module tables
  - PascalCase for classes
  - Examples:
    - Class: `local MyClass = class("MyClass")`
    - Module: `local arg_parser = {}` (table with static functions)
    - Function: `function arg_parser.parse(args)`
    - Variable: `local start_time = 0`
- **Modules vs Classes**:
  - **Modules**: Tables with static functions (no instances created)
    - Use snake_case naming: `arg_parser`, `utils`, etc.
    - Return the table directly: `return arg_parser`
    - Example: [app/arg-parser.lua](../app/arg-parser.lua)
  - **Classes**: Use custom class system for object-oriented code
    - Use PascalCase naming: `Client`, `Server`, `Session`
    - Create instances with `ClassName()`
    - Example: [app/client.lua](../app/client.lua)
- **Privacy**: Prefix private members with underscore (`_method`, `_field`)
- **Callbacks**: Named with `on_` prefix (`on_connect`, `on_disconnect`)
- **Type annotations**: Mandatory and strict - see [type-annotations.md](type-annotations.md) for the full rules

## Global Variables and Functions

Defined in [.luacheckrc](../.luacheckrc) and loaded via [app/globals.lua](../app/globals.lua):

- `app` - global Client or Server instance
- `config` - LÖVE config table, set in [conf.lua](../conf.lua)
- `class()` - class constructor; `abstract()` - marks abstract methods
- `is_instance_of()`, `get_class_name_of()`, `get_class_of()` - reflection
- `assert_type()`, `assert_unreachable()` - assertions
- `table.*` - extended table utilities (merge, find, serialization)
- `ripairs()`, `cipairs()`, `cripairs()`, `cpairs()`, `prev()` - reverse/cyclic iterators ([utils/table.lua](../utils/table.lua))
- `toboolean()` - value-to-boolean conversion
- `love.*` - LÖVE framework API
- `dump()` - debug dumping (only in debug mode)

Note: `Utils.get_time()`, `Utils.get_stack_trace()`, `Utils.draw_aabbs()` live in the [utils/utils.lua](../utils/utils.lua) module (required locally, not global). See [.luacheckrc](../.luacheckrc) for the authoritative globals list.

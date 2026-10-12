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
    - Type the module table with a PascalCase `global record` - e.g., `global record Media` for `local media: Media = {}` in [utils/media.tlt](../utils/media.tlt) (still-Lua modules: a PascalCase `---@class`)
    - Enums are Teal enums nested in the module's record - e.g., `Media.Type` in [utils/media.d.tl](../utils/media.d.tl)
    - Example: [app/arg-parser.tlt](../app/arg-parser.tlt)
  - **Classes**: Use custom class system for object-oriented code
    - Use PascalCase naming: `Client`, `Server`, `Session`
    - Create instances with `ClassName()`
    - Example: [app/client.lua](../app/client.lua)
- **Privacy**: Prefix private members with underscore (`_method`, `_field`)
- **Callbacks**: Named with `on_` prefix (`on_connect`, `on_disconnect`)
- **Dynamic dispatch (factory-like)**: When the concrete type of a value must be determined at runtime, follow the pattern in [utils/media.tlt](../utils/media.tlt) (`media.get_type_and_medium`):
  - Wrap each fallible constructor in a local `_try_`-prefixed function with a strict signature (e.g., `_try_create_image_file`)
  - List the candidates in an ordered dispatch table of `{constructor, tag}` pairs (e.g., `MATCH_FILE`), ordered so ambiguous data resolves to the preferred type
  - Iterate the table with `pcall`; the first constructor that succeeds determines the result - return the tag together with the constructed value
  - Tag results with an enum of the module (e.g., `Media.Type`) instead of magic strings or numbers
- **Types**: Mandatory and strict - see [types.md](types.md) for the full rules; ownership and destructors: [lifetime.md](lifetime.md)

## Global Variables and Functions

Declared in the modules' `.d.tl` fragments, listed for the remaining Lua in [.luacheckrc](../.luacheckrc), and loaded via [app/globals.tlt](../app/globals.tlt):

- `app` - global Client or Server instance
- `config` - LÖVE config table, set in [conf.lua](../conf.lua)
- `class()` - class constructor; `abstract()` - marks abstract methods
- `is_instance_of()`, `get_class_name_of()`, `get_class_of()` - reflection
- `assert_type()`, `assert_unreachable()` - assertions
- `ripairs()`, `cipairs()`, `cripairs()`, `cpairs()`, `prev()` - reverse/cyclic iterators ([utils/table.tlt](../utils/table.tlt))
- `toboolean()` - value-to-boolean conversion
- `love.*` - LÖVE framework API
- `dump()` - debug dumping (only in debug mode)

Not globals: the table helpers (merge, find, copy, serialization) are the module `table_utils` (`local table_utils = require("utils.table")`); `Utils.get_time()`, `Utils.get_stack_trace()`, `Utils.draw_aabbs()` live in the [utils/utils.tlt](../utils/utils.tlt) module; `lifetime` is required (`local lifetime = require("lifetime")`; generated code binds it itself). See [.luacheckrc](../.luacheckrc) for the authoritative globals list.

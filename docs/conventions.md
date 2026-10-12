# Code Conventions

- **Naming**:
  - snake_case for functions, variables, and module tables
  - PascalCase for classes
  - PascalCase for types too: a class's interface, a module's record, enums and aliases (`global type PointerId`)
  - Examples:
    - Class: `local MyClass: MyClass = class("MyClass")`
    - Module: `local arg_parser: ArgParser = {}` (table with static functions)
    - Function: `function arg_parser.parse(args: {string}): ArgParserResult`
    - Variable: `local start_time = 0`
- **Modules vs Classes**:
  - **Modules**: Tables with static functions (no instances created)
    - Use snake_case naming: `arg_parser`, `utils`, etc.
    - Return the table directly: `return arg_parser`
    - Type the module table with a PascalCase `global record` - e.g., `global record Media` for `local media: Media = {}` in [utils/media.tlt](../utils/media.tlt)
    - Enums are Teal enums nested in the module's record - e.g., `Media.Type` in [utils/media.d.tl](../utils/media.d.tl)
    - Example: [app/arg-parser.tlt](../app/arg-parser.tlt)
  - **Classes**: Use custom class system for object-oriented code
    - Use PascalCase naming: `Client`, `Server`, `Session`
    - Create instances with `ClassName()`
    - Example: [app/client.tlt](../app/client.tlt)
- **Files**: every module is `<dir>/<module>.tlt` (the implementation) and `<dir>/<module>.d.tl` (its declaration fragment: the module's public types and the globals it defines, every field of a class, private ones too; the LÖVE thread scripts, `app/globals.tlt` and the test modules, which define nothing global, have none); file names are kebab-case (`ui/form-screen.tlt`), required by dotted path (`require("ui.form-screen")`). A fragment declares only globals and never `require`s ([types.md](types.md), "Fragments and the Environment File")
- **Table helpers**: the module `table_utils` (`local table_utils = require("utils.table")`), never fields added to the standard `table`
- **Casts and `any`**: `x as T` only where the checker cannot know what the code knows (a love-api "table" result, a value read back from a channel or a serialized string, a test reaching past the types), and `any` only where values really are of any type; each carries a comment saying why, `-- as: ...` or `-- any: ...`, on its line or the lines above (one comment may cover a group: `-- as (both functions): ...`)
- **Privacy**: Prefix private members with underscore (`_method`, `_field`)
- **Callbacks**: Named with `on_` prefix (`on_connect`, `on_disconnect`)
- **Dynamic dispatch (factory-like)**: When the concrete type of a value must be determined at runtime, follow the pattern in [utils/media.tlt](../utils/media.tlt) (`media.get_type_and_medium`):
  - Wrap each fallible constructor in a local `_try_`-prefixed function with a strict signature (e.g., `_try_create_image_file`)
  - List the candidates in an ordered dispatch table of `{constructor, tag}` pairs (e.g., `MATCH_FILE`), ordered so ambiguous data resolves to the preferred type
  - Iterate the table with `pcall`; the first constructor that succeeds determines the result - return the tag together with the constructed value
  - Tag results with an enum of the module (e.g., `Media.Type`) instead of magic strings or numbers
- **Types**: Mandatory and strict - see [types.md](types.md) for the full rules; ownership and destructors: [lifetime.md](lifetime.md)

## Global Variables and Functions

Declared in the modules' `.d.tl` fragments (the authoritative list) and loaded via [app/globals.tlt](../app/globals.tlt); [.luacheckrc](../.luacheckrc) lists the few the Lua files use:

- `app` - global Client or Server instance ([app/app.d.tl](../app/app.d.tl))
- `config` - LÖVE config table, set in [conf.lua](../conf.lua) (declared in [app/app.d.tl](../app/app.d.tl))
- `class()` - class constructor; `abstract()` - marks abstract methods ([utils/class.d.tl](../utils/class.d.tl), with the reflection and assertion functions below)
- `is_instance_of()`, `get_class_name_of()`, `get_class_of()` - reflection
- `assert_type()`, `assert_unreachable()` - assertions
- `ripairs()`, `cipairs()`, `cripairs()`, `cpairs()`, `prev()` - reverse/cyclic iterators ([utils/table.tlt](../utils/table.tlt))
- `toboolean()` - value-to-boolean conversion
- `love.*` - LÖVE framework API
- `dump()` - debug dumping (only in debug mode; [utils/dump.d.tl](../utils/dump.d.tl))
- `loadstring` - Lua 5.1's, which Teal's standard library lacks ([types/lua51.d.tl](../types/lua51.d.tl))

Not globals: the table helpers (merge, find, copy, serialization) are the module `table_utils` (`local table_utils = require("utils.table")`); `Utils.get_time()`, `Utils.get_stack_trace()`, `Utils.draw_aabbs()` live in the [utils/utils.tlt](../utils/utils.tlt) module; `lifetime` needs no `require` in a `.tlt`: the transpiler binds it (`local lifetime = require("lifetime")`) in the header of every module that uses `@`, `!@` or `lifetime`.

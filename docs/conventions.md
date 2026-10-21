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
  - **Modules**: tables with static functions (no instances created)
    - Use snake_case naming: `arg_parser`, `utils`, etc.
    - Return the table directly: `return arg_parser`
    - Annotate the module table with a `---@class` named after the module, in
      snake_case, so the language server can type it (`---@class media`
      above `local media = {}`)
    - Constant tables acting as enums are annotated `---@enum`
      (`---@enum media.Type`)
  - **Classes**: use the custom class system for object-oriented code
    - Use PascalCase naming: `Client`, `Server`, `Session`
    - Create instances with `ClassName()`
- **Privacy**: prefix private members with underscore (`_method`, `_field`)
- **Callbacks**: named with `on_` prefix (`on_connect`, `on_disconnect`)
- **Destructors**: `release(reason)` is the destructor lua-lifetime runs when
  the object dies; it is never called by hand, and rarely written: a tree
  node takes its subtree, a screen its control tree, a connection frees its
  LÖVE objects, a remote procedure its handler slot; registrations on events
  and hit-tested managers end by themselves when the owner dies. An override
  chains the base class's as `init` does (`Control.release(self, reason)`).
  Objects are anchored where they are created, by chaining the method every
  class instance has: `self._x = X(...):attach_lifetime(self)` (a token or
  another plain object: `lifetime.attach(obj, owner)`); constructors never
  anchor themselves; a control is not anchored to its parent, the tree does
  that. A root class is annotated `---@class X: Object` so the language
  server sees the method. See [lifetimes.md](lifetimes.md).
- **Dynamic dispatch (factory-like)**: when the concrete type of a value must
  be determined at runtime, follow the pattern of the media module
  (`media.get_type_and_medium`):
  - Wrap each fallible constructor in a local `_try_`-prefixed function with
    a strict signature (e.g. `_try_create_image_file`)
  - List the candidates in an ordered dispatch table of `{constructor, tag}`
    pairs, ordered so ambiguous data resolves to the preferred type
  - Iterate the table with `pcall`; the first constructor that succeeds
    determines the result: return the tag together with the constructed value
  - Tag results with an `---@enum` table on the module (`media.Type`) instead
    of magic strings or numbers
- **Comments**: code defends itself; a comment is written only for a gotcha
  the code cannot show (an ordering that matters, a host quirk, a type the
  language server cannot express). What a function does is its name, its
  annotations and its body.
- **Type annotations**: mandatory and strict; see
  [type-annotations.md](type-annotations.md) for the full rules

## Global Variables and Functions

Declared for the linter and loaded by the globals module at startup:

- `app` - global Client or Server instance
- `config` - LÖVE config table, set in the LÖVE configuration callback
- `class()` - class constructor; `abstract()` - marks abstract methods
- `is_instance_of()`, `get_class_name_of()`, `get_class_of()` - reflection
- `assert_type()`, `assert_unreachable()` - assertions
- `table.*` - extended table utilities (merge, find, serialization)
- `ripairs()`, `cipairs()`, `cripairs()`, `cpairs()`, `prev()` - reverse and
  cyclic iterators
- `toboolean()` - value-to-boolean conversion
- `love.*` - LÖVE framework API
- `dump()` - debug dumping (only in debug mode)

`Utils.get_time()`, `Utils.get_stack_trace()` and `Utils.draw_aabbs()` live
in the utils module (required locally, not global). The linter configuration
is the authoritative list of globals.

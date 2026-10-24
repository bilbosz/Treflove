# Type Annotations

Type annotations use LuaDoc format (`---@class`, `---@param`, `---@return`,
`---@field`, `---@alias`) and are **mandatory**: all functions, methods,
classes, and class fields must have type annotations - untyped code is not
acceptable.

## Strict Types - Avoid `table` and `any`

A bare `table` or `any` defeats the type checker; always use the most
specific type available:

- Concrete class types: `Connection`, `Session`, `Control`
- Typed tables: `table<K, V>` for maps (e.g. `table<Connection, Session>`),
  `V[]` for arrays
- Table shapes: `{name: string, size: number}` or tuples like
  `{[1]: number, [2]: function}`
- Unions instead of `any`: `string|number`, `Control|nil`
- `any` is acceptable only where truly arbitrary values are handled
  (serialization, debug dumping), and where the language server cannot
  express the type, such as a table of class tables (constructors)

## Aliases

- **Userdata and opaque types**: wrap `userdata`/`lightuserdata` and other
  non-obvious primitive types in a named `---@alias` so the intent is
  documented and reusable:
  - `---@alias PointerId number|lightuserdata|nil` - mouse button, touch id,
    or hover
  - `---@alias LoveMedium love.Source|love.Image|love.Font|love.Video|nil`
- **Callbacks**: `---@alias CallbackName fun(param:Type)` - name callback
  signatures instead of repeating inline `fun(...)` types
  (`ConnectionRequestHandler`, `PointerEventHandler`)

## Annotation Rules

- **Parameters**: always annotate function parameters with
  `---@param name Type`
- **Return values**: only annotate return types when functions **do** return
  values, using `---@return Type`
- **Void functions**: do not annotate functions that return nothing - no
  `---@return void` or similar
- **Classes**: all classes must have a `---@class ClassName` annotation
  - Single inheritance: `---@class ClassName : BaseClass`
  - Multiple inheritance: `---@class ClassName : BaseClass1, BaseClass2`
    (supported by the custom class system)
  - A root class: `---@class ClassName : Object`, the type-level base that
    carries the methods every instance has
  - A mixin that is not a Control at runtime but is always mixed into one
    (`Input`) is annotated `: Control`, which is what its methods see
- **Fields**: class fields are documented with `---@field name Type`; for
  constant tables with literal values the language server infers the types,
  so explicit field annotations are optional there
- **Variadic functions**: document the variadic parameter with
  `---@param ... Type`
- **Enums**: constant tables used as enums are annotated `---@enum Name` so
  values can be typed as the enum instead of `number`/`string`
- **Module tables**: modules (snake_case tables, not instantiated) still get
  a `---@class` annotation so the language server can type them
- **Module type names**: a module's type is named after the module, in
  snake_case, the same name as the module table, so the annotation and the
  variable read alike:
  ```lua
  ---@class module
  local module = {}
  ```
  A value typed as the module uses that name too: `---@type module`
- **Abstract methods**: `abstract()` raises and is typed as returning `any`,
  so an overridable method that returns a value forwards it:
  `return abstract()`

## Strict Checks

The language server runs with `no-unknown` and the parameter check on, so
the diagnostics are empty only when every value has a known type. In
practice:

- **A local the server cannot infer** (declared without a value, assigned
  in several branches, a `pcall` result) is declared: `---@type Input|nil`
  above `local found`; `---@type boolean, any` above
  `local ok, err = pcall(...)`
- **Loop variables inside a `---@generic` function** get `---@param k any`
  / `---@param v any` lines above the `for`: the server cannot name the
  function's own type parameters there
- **What the runtime guarantees but the server cannot see** is narrowed
  where it is used, with `assert` or an `if` that reads naturally
  (`local data = assert(app.data)`, `if not client then ... return end` on
  a socket result). A cast (`--[[@as X]]`) is the last resort, for a value
  with no natural check: a decoded wire message, `love.data.decode` with
  the `"string"` container, a message popped from a channel
- **A field that is absent on one side or at some time is `|nil`**, with a
  description saying when it exists (`App.session`: the client's, while
  connected; `App.root`, `App.width`: with a window; `App.data`: on the
  server from `load()` on). Fields that are always set on an instance are
  not `|nil`, even when only one side has the instance
- **Thread scripts** (`networking/detail/`) receive their arguments from
  `love.thread`; one `---@type A, B, C` line above the unpacking `local`
  types them. The `enet` module they use is typed by the hand-written
  package `annotations/enet` (`enet.host`, `enet.peer`, `enet.event`)
- **Class tables**: the constructor plugin types a class table as its class
  joined by a constructor overload, which the `Class` alias in the class
  system names (`assert_type(x, Aabb)` takes `type|Class`). The overload
  comes from the `---@param` lines of `init`, so every `init` is fully
  annotated; a class without an `init` of its own gets a hand-written
  `---@overload fun(...): X` on its class line
- **Subclasses narrow inherited fields and accessors** by redeclaring them
  on their class line: a `Model` subclass declares `---@field data
  TokenData` and `---@field get_data fun(self: Token): TokenData`, the
  base keeps `table`; `Control` redeclares the tree accessors it inherits
  with `Control` types. The language server does not resolve a generic
  base class (`Model<T>`) through a subclass line, so this is the way
- **Remote procedures**: every request and response class derives from
  `RequestBody` / `ResponseBody` (`networking/connection.lua`), what the
  connection and the abstract base `RemoteProcedure` handle
- **The persisted game state** is `GameData` (`game/game-data-rp.lua`),
  with `PageData` and `TokenData` next to the classes that wrap them
- **Tests**: a fake is typed as what it fakes (`---@class FakeChannel:
  love.Channel`, `AppMock: App`), so production code never sees a union of
  the real type and a mock. A test that passes a wrong type on purpose, to
  assert the runtime error, marks the line with
  `---@diagnostic disable-next-line: param-type-mismatch`; private access
  from a test is marked `invisible`. These two are the only suppressions:
  a diagnostic is otherwise fixed by making the type right, never by
  `---@diagnostic disable` or a cast to `any`

## LÖVE Framework Types

Use the specific LÖVE types from the annotation package
(`love.KeyConstant`, `love.Font`, `love.DroppedFile`) instead of generic
types like `string` or `any`:

- Never annotate a LÖVE object as bare `userdata` or `table`: every LÖVE
  object has a typed class in the annotation package, one file per LÖVE
  module (`love.Thread` and `love.Channel` with the thread module,
  `love.Image` and `love.Font` with graphics, `love.File` and
  `love.DroppedFile` with the filesystem)
- Object types are declared as `---@class love.X` (e.g.
  `love.Channel: love.Object`); enums are string aliases (`love.KeyConstant`);
  LÖVE callbacks are function aliases (`love.keypressed`)
- When unsure of a type name, search the annotation package:
  `rg -e "---@class love\." annotations/`

## Annotation Packages for External Libraries

The annotation packages are type definitions for external libraries, read by
the language server for autocomplete, type checking and diagnostics:

- They are git submodules maintained upstream, often auto-generated:
  **do not edit** them by hand; update them with
  `git submodule update --init --recursive`. The one exception is
  `annotations/enet`, written here from LÖVE's lua-enet binding because
  no upstream package exists; it is edited when the binding changes
- They are listed in the language server's workspace library configuration
  at the repository root
- The external library's documentation is in the annotation files; for
  example, `love.keypressed` is documented as
  ```lua
  ---Callback function triggered when a key is pressed.
  ---@alias love.keypressed fun(key: love.KeyConstant, scancode: love.Scancode, isrepeat: boolean)
  ```
- See the annotations folder's own guide for adding a package

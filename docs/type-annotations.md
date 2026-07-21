# Type Annotations

Type annotations use LuaDoc format (`---@class`, `---@param`, `---@return`, `---@field`, `---@alias`) and are **mandatory**: all functions, methods, classes, and class fields must have type annotations - untyped code is not acceptable.

## Strict Types - Avoid `table` and `any`

A bare `table` or `any` defeats the type checker; always use the most specific type available:

- Concrete class types: `Connection`, `Session`, `Control`
- Typed tables: `table<K, V>` for maps (e.g., `table<Connection, Session>`), `V[]` for arrays
- Table shapes: `{name: string, size: number}` or tuples like `{[1]: number, [2]: function}` (see `DeferEntry` in [events/defer-manager.lua](../events/defer-manager.lua))
- Unions instead of `any`: `string|number`, `Control|nil`
- `any` is acceptable only where truly arbitrary values are handled (e.g., serialization in [utils/table.lua](../utils/table.lua), debug dumping)

## Aliases

- **Userdata and opaque types**: Wrap `userdata`/`lightuserdata` and other non-obvious primitive types in a named `---@alias` so the intent is documented and reusable. Existing examples:
  - `---@alias PointerId number|lightuserdata|nil` ([events/pointer-event.lua](../events/pointer-event.lua)) - mouse button, touch id, or hover
  - `---@alias LoveMedium love.Source|love.Image|love.Font|love.Video|nil` ([utils/media.lua](../utils/media.lua))
- **Callbacks**: `---@alias CallbackName fun(param:Type)` - name callback signatures instead of repeating inline `fun(...)` types (e.g., `ConnectionRequestHandler` in [networking/connection.lua](../networking/connection.lua))

## Annotation Rules

- **Parameters**: Always annotate function parameters with `---@param name Type`
- **Return values**: Only annotate return types when functions **DO** return values using `---@return Type`
- **Void functions**: Do NOT annotate functions that return nothing - no `---@return void` or similar
- **Classes**: All classes must have `---@class ClassName` annotation
  - For single inheritance: `---@class ClassName : BaseClass`
  - For multiple inheritance: `---@class ClassName : BaseClass1, BaseClass2, BaseClass3`
  - Multiple inheritance is supported by the custom class system (see [utils/class.lua](../utils/class.lua))
- **Fields**: Class fields should be documented with `---@field name Type`
  - For constants/configuration tables with literal values, the Lua language server can infer types automatically - explicit field annotations are optional
- **Variadic functions**: Functions using `...` should document the variadic parameter with `---@param ... Type`
- **Enums**: Constant tables used as enums are annotated with `---@enum Name` so values can be typed as the enum instead of `number`/`string` - e.g., `---@enum Media.Type` in [utils/media.lua](../utils/media.lua)
- **Module tables**: Modules (snake_case tables, not instantiated) still get a PascalCase `---@class` annotation so the language server can type them - e.g., `---@class Media` in [utils/media.lua](../utils/media.lua)

## LÖVE Framework Types

Use specific LÖVE types from annotations (e.g., `love.KeyConstant`, `love.Font`, `love.DroppedFile`) instead of generic types like `string` or `any`:

- Never annotate a LÖVE object as bare `userdata` or `table` - every LÖVE object has a typed class in the annotations package
- Type definitions live under `annotations/love2d/library/`, one file per LÖVE module - e.g., [love/thread.lua](../annotations/love2d/library/love/thread.lua) defines `love.Thread` and `love.Channel`, [love/graphics.lua](../annotations/love2d/library/love/graphics.lua) defines `love.Image` and `love.Font`, [love/filesystem.lua](../annotations/love2d/library/love/filesystem.lua) defines `love.File` and `love.DroppedFile`
- Object types are declared as `---@class love.X` (e.g., `love.Channel: love.Object`); enums are string aliases declared as `---@alias` (e.g., `love.KeyConstant`); LÖVE callbacks are function aliases in [annotations/love2d/library/love.lua](../annotations/love2d/library/love.lua) (e.g., `love.keypressed`)
- When unsure of a type name, search the annotations: `rg -e "---@class love\." annotations/love2d/library/`

## Annotation Packages for External Libraries

The [annotations/](../annotations/) folder contains type definition packages for external libraries used by the Lua language server. These provide autocomplete, type checking, and diagnostics for frameworks like LÖVE.

- Annotation packages are typically git submodules maintained in upstream repositories
- **DO NOT manually edit** annotation files - they are often auto-generated
- Integrated via `workspace.library` setting in [.luarc.json](../.luarc.json)
- Update submodules with: `git submodule update --init --recursive`
- **External library documentation** can be found within annotation files. For example, `love.keypressed` is documented in [annotations/love2d/library/love.lua](../annotations/love2d/library/love.lua):
  ```lua
  ---Callback function triggered when a key is pressed.
  ---@alias love.keypressed fun(key: love.KeyConstant, scancode: love.Scancode, isrepeat: boolean)
  ```
- See [annotations/CLAUDE.md](../annotations/CLAUDE.md) for details on adding new annotation packages

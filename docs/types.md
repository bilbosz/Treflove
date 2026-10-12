# Types

Converted modules are Teal (`.tlt`, Teal plus the lifetime extension of
[lifetime.md](lifetime.md)); their types live in declaration fragments
(`.d.tl`). The build ([development.md](development.md), "The Build")
type-checks everything; untyped code is not acceptable.

## Fragments and the Environment File

Every module `<dir>/<module>.tlt` has a fragment `<dir>/<module>.d.tl`
holding its public types and the globals it defines. The build concatenates
all fragments into one predefined file, `build/types/env.tl`, so every
fragment and every module sees every global type. Rules:

- A fragment declares only globals: `global interface`, `global record`,
  `global enum`, `global type`, `global name: Type`. It never `require`s;
  it names global types, `lifetime.*` (the environment file starts with
  `local lifetime = require("lifetime")`) and `love.*`.
- Other type names may be used before their declaration (Teal resolves them
  lazily within the one file); the bases of an interface (`is A, B`) may
  not, so the build orders fragments by their `is` clauses.
- An error in a fragment is reported at the fragment's own line.
- A fragment of a module that is still Lua may be **partial**: it declares
  only what converted modules use and says so in a comment
  ([controls/control.d.tl](../controls/control.d.tl)); the phase that
  converts the module completes it.

## Classes

Teal records cannot inherit from records, but interfaces can inherit from
several interfaces, and a variable typed by an interface accepts function
definitions for the fields the interface declares. So the **instance type**
of a class is a global interface, and the **class table** is a variable
typed by the same interface:

```teal
-- controls/rectangle.d.tl
global interface Rectangle is Control
    _color: {number}                       -- every field, private ones too
    set_color: function(self, color: {number})
    get_color: function(self): {number}
end
```

```teal
-- controls/rectangle.tlt
local Control = require("controls.control")

local Rectangle: Rectangle = class("Rectangle", Control)

Rectangle.init = function(self: Rectangle, color: {number})
    Control.init(self)                     -- super call on the base class table
    self._color = color
end

function Rectangle:set_color(color: {number})
    self._color = color
end

function Rectangle:get_color(): {number}
    return self._color
end

return Rectangle
```

- The root interface `Object` ([utils/class.d.tl](../utils/class.d.tl))
  declares `metamethod __call` (so `Rectangle(...)` is a `Rectangle`),
  `init` and `release`. Every class interface is `Object` through its
  bases; a mixin is one more interface in the `is` list (`global interface
  TextButton is Text, Input`). Same-named fields of the bases must have
  the same type.
- **Constructors are assigned** (`X.init = function(self: X, ...) ... end`),
  not defined with `function X:init`: Teal rejects a definition whose
  signature differs from the inherited `init: function(self, ...: any)`, but
  accepts assigning a narrower function. **Limitation:** constructor
  arguments are not checked at call sites (`Rectangle(1, 2)` passes
  `any...`); constructor bodies are fully typed.
- Every other method is defined with `function X:method(...)` and is
  checked against the interface, `release` included: it keeps the parameter
  `reason?: LifetimeReason` even when the body ignores it.
- Super calls are `Base.method(self, ...)` on the required base class table.
- Abstract methods are declared in the interface and assigned
  `X.method = abstract()` (`abstract` is generic in its result).
- `class`, `is_instance_of`, `get_class_of`, `get_class_name_of`,
  `assert_type`, `assert_unreachable` and `abstract` are globals declared
  in [utils/class.d.tl](../utils/class.d.tl).

## Modules

A module (a table of functions, never instantiated) is a `global record`
with a PascalCase type and a snake_case local in its `.tlt`:

```teal
-- app/arg-parser.d.tl
global record ArgParser
    parse: function(args: {string}): ArgParserResult
end
```

```teal
-- app/arg-parser.tlt
local arg_parser: ArgParser = {}
function arg_parser.parse(args: {string}): ArgParserResult ... end
return arg_parser
```

Treflove's table helpers are the module `table_utils` (type `TableUtils`,
[utils/table.tlt](../utils/table.tlt)), required where used:
`local table_utils = require("utils.table")`; Teal does not allow adding
fields to the standard `table`. The iterators (`ripairs`, `cipairs`,
`cripairs`, `cpairs`, `prev`) and `toboolean` stay globals.

## Translating Types

| LuaDoc | Teal |
| --- | --- |
| `number[]` | `{number}` |
| `[number, number]` | `{number, number}` |
| `table<K, V>` | `{K: V}` |
| `fun(a: T): R` | `function(a: T): R` |
| `X\|nil` | `X` (every Teal type is nilable) |
| optional parameter | `name?: T` |
| anonymous shape `{name: string}` | a named `global record` in the fragment |
| `---@alias` | `global type` |
| `---@enum` | an `enum` nested in the module's record (`Media.Type`), or a top-level `global enum` for a class |

- Teal enums are strings: an enum's values are its names
  (`Media.Type` is `"IMAGE"`, `"AUDIO"`, ...).
- A union may hold at most one table type; a union of several interfaces
  is spelled by their common supertype (`LoveMedium = love.Object`).
- `any` only where values really are of any type (serialization, debug
  dumping, event arguments), and every `any` carries a comment saying why.
- An interface with an array part puts it first: `global interface Aabb is
  {number}, Object`.

## LÖVE and Host Types

- [types/love.d.tl](../types/love.d.tl) is **generated** by
  [tools/gen-love-types.lua](../tools/gen-love-types.lua) from
  `lib/love-api` (LÖVE 11.5); never edit it, fix the generator. `global
  record love` holds the modules as nested records (`love.graphics`), the
  object types as interfaces with their supertypes (`love.Image is
  love.Texture, love.Drawable, love.Object`), the enums (`love.KeyConstant`),
  function variants as overloads and the callbacks as assignable fields
  (`love.load`, `love.quit`, ...). A love-api "table" is `{any:any}`;
  "Variant", "light userdata" and "cdata" are `any`.
- Other host libraries Teal does not know get hand-written declarations in
  [types/](../types/): [socket.d.tl](../types/socket.d.tl) (the module
  `socket`), [lua51.d.tl](../types/lua51.d.tl) (`loadstring`). Teal's
  standard library is Lua 5.4's; `tl` generates 5.1 compatibility code,
  so write `table.unpack`, not `unpack`.
- The global `app` is `App` ([app/app.d.tl](../app/app.d.tl)); `config`
  (the LÖVE configuration table kept by `conf.lua`) is `LoveConfig`.

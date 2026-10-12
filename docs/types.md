# Types

Every module is Teal (`.tlt`, Teal plus the lifetime extension of
[lifetime.md](lifetime.md)), except the bootstraps `main.lua` and
`conf.lua`, the tests and the tools; the modules' types live in declaration fragments
(`.d.tl`). The build ([development.md](development.md), "The Build")
type-checks everything; untyped code is not acceptable.

## Fragments and the Environment File

Every module `<dir>/<module>.tlt` has a fragment `<dir>/<module>.d.tl`
holding its public types and the globals it defines (the LÖVE thread
scripts of [networking/detail/](../networking/detail/), which nothing
requires and which define nothing, have none). The build concatenates
all fragments into one predefined file, `build/types/env.tl`, so every
fragment and every module sees every global type. Rules:

- A fragment declares only globals: `global interface`, `global record`,
  `global enum`, `global type`, `global name: Type`. It never `require`s;
  it names global types, `lifetime.*` (the environment file starts with
  `local lifetime = require("lifetime")`) and `love.*`.
- Other type names may be used before their declaration (Teal resolves them
  lazily within the one file); the interfaces a type is (`is A, B`, on an
  interface or a record) may not, so the build orders fragments by their
  `is` clauses, and within a fragment a base comes first.
- An error in a fragment is reported at the fragment's own line.
- Every module has its fragment; its first line names the module
  (`-- game/session.tlt: ...`) and, where the constructor takes arguments
  the checker cannot see at call sites, spells them in a comment
  (`constructor: Token(data: TokenData, parent: Control)`).

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
- A required class table whose name the file also uses as a type is
  declared with that type: `local Control: Control =
  require("controls.control")`. An inferred local (`local Control =
  require("controls.control")`) shadows the global type of the same name,
  and every later `Control` annotation in the file is an `unknown type`.
- Abstract methods are declared in the interface and defined with a body
  that calls `abstract()`: `function X:method(_a: A): R return abstract()
  end` (`abstract` is generic in its result). It raises when it runs, so
  `X.method = abstract()` would raise while the module loads.
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

## What the Checker Takes and Refuses

Found while declaring the whole codebase; the build reports each at the
fragment's line.

- A subinterface may **redeclare** an inherited field with a narrower type:
  a field (`parent: Control` in `Control is Tree`), a method parameter
  (`add_child: function(self, child: Control)`), or a method's body records
  (each remote procedure redeclares `send_request`, `send_response` and
  `receive_response` with its own `RequestBody`/`ResponseBody` records,
  [networking/remote-procedure.d.tl](../networking/remote-procedure.d.tl)).
- A redeclared field is compared with the inherited one **nominally where an
  alias is involved**: two different function aliases never match, and a
  record never matches a map alias. Spell the inherited type out
  (`Model.data: {string: any}`, the callback of a redeclared `send_request`
  written `function(response: LoginResponse)`).
- A record is a subtype of `{string: any}`, but not of `{string | number:
  any}`; `ModelData` is therefore keyed by strings, so `Token.data` narrows
  to `TokenData`.
- Two bases of a multiple-inheritance class must agree on every field they
  both declare (`field 'x' does not match definition in interface B`).
- An interface may exist only as a type: `Input is Control` (the mixin is
  always mixed into a control), `PreviewComponent` (what `PreviewImageArea`
  and `PreviewAudioArea` have in common, since a union may hold one table
  type only). Such a type has no class table, so `is_instance_of` cannot
  take it.
- Function parameters are compared **bivariantly**: a function whose
  parameter is a subtype or a supertype of the expected one is accepted
  (`function(x: Page)` where `function(x: Control)` is expected, and the
  other way round), an unrelated type is not; the `self` parameter of a
  method taken as a value (`self.on_update`) is not compared at all.
  `Event.register` is generic in the owner (`register: function<O is
  Object>(self, owner: O, handler: function(owner: O, ...: any))`), so an
  owner must be an `Object` and a handler written as a plain function must
  take that owner; a consumer passes its method as it is,
  `app.update_event:register(self, self.on_update)`, with no cast.
- `table.unpack` of a `{number}` passed straight to a function counts as
  two arguments (`wrong number of arguments (given 2, ...)`); a tuple
  (`{number, number}`) is counted right. Pass the table where the callee
  takes one (`love.graphics.setColor(color)`).
- A main chunk's `...` is typed as strings (command-line arguments). A
  LÖVE thread script receives what `Thread:start` passed, so it casts:
  `local data, channel = ... as (ModelData, love.Channel)`
  ([networking/detail/](../networking/detail/)). Assigning an uncast `...`
  value to a local of another type crashes `tl` (an assertion in
  `errors.at`) instead of reporting the mismatch.
- A local initialised with an integer literal is an `integer`
  (`local y = 250`), and a later `number` cannot be assigned to it
  (`got number, expected integer`); declare it `local y: number = 250`.
- A function's extra results are not dropped where a single value is
  returned: `return utf8.len(s)` from a function declared `: integer` is
  `excess return values` (`utf8.len` also returns a position);
  parenthesize to keep the first, `return (utf8.len(s))`.
- A hook kept in a field (`self._unlink_hook = f !@ (a, b)`, a named hook)
  is a `lifetime.Hook` ([ui/input.d.tl](../ui/input.d.tl)).
- `string.format`'s `%i` takes an integer, not a numeric string (Lua 5.1
  would coerce it): `math.floor(tonumber(port))`.
- `userdata` is a type (`PointerId = number | userdata`: a mouse button or a
  touch id).
- A love-api "table" result (`love.filesystem.getInfo`) is `{any: any}`;
  read a field with a cast (`info.type as love.FileType`).
- A LÖVE callback is assigned (`love.update = function(dt: number) ...
  end`), not defined with `function love.update`, for the same reason as a
  constructor; a function with fewer parameters than the callback field is
  accepted, one with fewer results is not: `love.errorhandler` is typed to
  return LÖVE's error loop, so a handler that wants none returns `nil`
  ([app/app.tlt](../app/app.tlt)).
- Teal's standard library is Lua 5.4's, which has no `math.pow`: write
  `x ^ y`.
- The lifetime transpiler (not `tl`) takes a method call that opens a
  table constructor for a typed field: `{token:get_position()}` is the
  syntax error `'=' expected near '('`. Bind the results to locals first
  (`local x, y = token:get_position()`, then `{x, y}`;
  [game/page/page.tlt](../game/page/page.tlt)).

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
  `socket`: the clock and the TCP sockets of the connection threads),
  [love/filesystem.d.tl](../types/love/filesystem.d.tl) (the module
  `love.filesystem`, which a thread script requires: a LÖVE thread starts
  with no LÖVE module loaded), [utf8.d.tl](../types/utf8.d.tl) (the module `utf8`),
  [lua51.d.tl](../types/lua51.d.tl) (`loadstring`). Teal's
  standard library is Lua 5.4's; `tl` generates 5.1 compatibility code,
  so write `table.unpack`, not `unpack`.
- The global `app` is `App` ([app/app.d.tl](../app/app.d.tl)); `config`
  (the LÖVE configuration table kept by `conf.lua`) is `LoveConfig`.

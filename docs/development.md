# Development

## Running the Application

The app runs from `build/`, so build first (`./run.sh` does):
```bash
./build-code.sh
```

Run server only:
```bash
love . server localhost 8080
```

Run client only:
```bash
love . client localhost 8080
```

Build, then run both server and client together:
```bash
./run.sh
```

## Source Layout

Treflove is written in Teal with the lua-lifetime extension (see
[types.md](types.md) and [lifetime.md](lifetime.md)). A module is two
files:

- `<dir>/<module>.d.tl` - its declaration fragment: the module's public
  types (`global interface`, `global record`, `enum`, `global type`) and
  the globals it defines
- `<dir>/<module>.tlt` - its implementation: Teal plus the lifetime
  extension (`@`, `!@`, `lifetime.scope`)

A module is required by its dotted path (`require("utils.class")`), which
resolves to the built `build/utils/class.lua`. The only Lua sources are
`main.lua`, `conf.lua` and `tests/run.lua`, which put `build/` first on the
require path, and the build tools under `tools/`; every module, test
module and test helper is a `.tlt`. The submodules under `lib/` are the toolchain:
[lib/tl](../lib/tl) (the Teal compiler, pinned to master `c6b986e`, since
the 0.24.8 release needs compat53 under Lua 5.1 and crashes without it),
[lib/lua-lifetime](../lib/lua-lifetime) (the transpiler and runtime) and
[lib/love-api](../lib/love-api) (the LÖVE 11.5 API description). After a
clone: `git submodule update --init`.

## The Build

```bash
./build-code.sh                   # rebuild everything into build/ (from scratch)
./build-code.sh utils/tree.tlt    # check and generate only these files
```

[tools/build.lua](../tools/build.lua) runs under `luajit` (or `lua5.1`):

1. **Environment file.** Every `*.d.tl` fragment (outside `lib/`, `build/`
   and `types/`) is concatenated into `build/types/env.tl` behind
   `local lifetime = require("lifetime")`, with a `-- @file PATH` line
   before each. Fragments are sorted by path, except that a fragment
   declaring a type named in another's `is` clause comes first (Teal does
   not resolve interface bases lazily). One file, because Teal resolves
   other type names lazily only within one file, and Treflove's types are
   cyclic through the global `app`. Fragments never `require`; they name
   global types, `lifetime.*` and `love.*`.
2. **Transpile.** lua-lifetime's pipeline with its Teal dialect turns each
   `X.tlt` into `build/tl/X.tl`, every statement on its source line.
3. **Type-check and generate.** One `tl` environment predefines
   [types/*.d.tl](../types/) and the environment file, checks every
   `build/tl/X.tl` (a `require("a.b")` resolves to `build/tl/a/b.tl`) and
   writes `build/X.lua`. The environment file is also checked as a file of
   its own (tl drops the errors of a predefined module), so an unknown type
   in a fragment is an error.
4. **Runtime.** `lib/lua-lifetime/lifetime/init.lua` is copied to
   `build/lifetime/init.lua`.

Errors read `FILE:LINE:COL: message` - for a `.tlt` the line is the source
line and the column the generated Teal's; for a fragment, the fragment's
own line - and the build exits 1. `tl`'s warnings (an unused variable, a
hint such as `pairs` on an array) are errors too, read `FILE:LINE:COL:
warning (TAG): message`, since the tree is clean of them; the two warnings
the class recipe causes in every class are not reported: a class table
shadowing the type of its name (`local Control: Control =
require("controls.control")`; for a local interface in a test, also the
"unused type" tl then reports for it) and a super call
(`Base.init(self)`) ([types.md](types.md), "Classes"). Success prints one line (`N modules
built`). The build is the type checker: there is no separate check step.
A full build takes a few seconds.

`types/love.d.tl` is generated from `lib/love-api` and committed; to
regenerate it after changing [tools/gen-love-types.lua](../tools/gen-love-types.lua):
```bash
luajit tools/gen-love-types.lua
```

## Development Commands

Lint the Lua files - `main.lua`, `conf.lua`, `tests/run.lua`, `tools/` and the data file `server/save.lua` (uses luacheck, config in [.luacheckrc](../.luacheckrc); `build/` and `lib/` excluded):
```bash
./lint-code.sh [target_path]
```

The `lint-code.sh` script accepts an optional `target_path` (file or directory) and defaults to linting the entire project.

Build, then run the automated test suite:
```bash
./test-code.sh
```

The `test-code.sh` script builds, then prefers plain `luajit` (fast, headless) and falls back to `love . test` (runs the same suite inside LÖVE with the real `love.*` APIs). Both must pass; after a build, run the LÖVE one with:
```bash
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . test
```

Verify changes with `./build-code.sh`, `./test-code.sh`, `love . test`, `./lint-code.sh`, and by running the app (`./run.sh`; headless server: `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 5 love . server localhost 8080`; the client needs a window, so without a display run it under Xvfb: `xvfb-run -a love . client localhost 8080`).

## Continuous Integration

GitHub Actions ([.github/workflows/ci.yml](../.github/workflows/ci.yml)) runs on every push; both jobs check out the submodules and build first:

- **Build, test, lint**: `./build-code.sh`, `./test-code.sh` (LuaJIT), `./lint-code.sh`
- **Test (LÖVE)**: `./build-code.sh`, then the same suite via `love . test`, headless with dummy SDL video/audio drivers

## Tests

The suite lives in [tests/](../tests/) and has no external dependencies. Its
modules are Teal, built with everything else into `build/tests/`:

- [tests/run.lua](../tests/run.lua) — entry point (Lua); lists test modules in `TEST_MODULES` (add new files there); requires the modules from `build/`, and under plain LuaJIT preloads a `socket` stub and the `utf8` shim
- [tests/lib/test.tlt](../tests/lib/test.tlt) — assertion framework: `test.suite(name)`, `test.case(name, fn)`, `assert_eq`, `assert_true/false`, `assert_near`, `assert_error`, `assert_deep_eq`
- [tests/lib/mocks.tlt](../tests/lib/mocks.tlt) — test doubles: `install_app()` (fake global `app`, typed `mocks.AppMock`, an `App` with a controllable clock and captured logs), `make_channel()`/`make_thread()` (in-memory LÖVE channel/thread stand-ins, `mocks.FakeChannel`/`mocks.FakeThread`), `make_keyboard()` (fake `love.keyboard` backend for `TextEventManager`), `ensure_love_data()` (real `love.data` under LÖVE, reversible fake under plain LuaJIT), `ensure_love_math()` (real `love.math` under LÖVE, a transform that ignores every operation under plain LuaJIT, enough to construct a `Control` or a `Screen`), `ensure_love_login()` (real `love.data` hashing/encoding, `love.math` generator and `love.thread` channels under LÖVE; deterministic stand-ins under plain LuaJIT, for a login and a Connector)
- [tests/lib/utf8-shim.tlt](../tests/lib/utf8-shim.tlt) — pure-Lua `utf8.len/offset/codes`, preloaded by `tests/run.lua` under plain LuaJIT (LÖVE bundles the real `utf8`)
- Test files are named `test-<module>.tlt`, one per module under test

Conventions: pure calculation modules (`utils/aabb`, `utils/table`, `utils/class`, `app/arg-parser`) are tested with plain asserts; modules with runtime dependencies (event managers, `DeferManager`, `BackstackManager`, `Connection`/`RemoteProcedure`, `FormScreen`/`Input`, `Session` with a client and a server app back to back and a test double for the screen layer, [tests/test-session.tlt](../tests/test-session.tlt)) get mocks from `tests/lib/mocks.tlt` instead of the real `app`/LÖVE objects. Test code is typed like production code. Classes defined inside test files use a `Test` name prefix (e.g. `TestEchoRp`) so they can't collide with production class names, and are typed by a `local interface` in the test module (the class recipe of [types.md](types.md) works with a local interface; the build does not report the shadowing it causes). Types a test needs from a helper are nested in the helper's module record and named through it (`mocks.AppMock`). Where a test reaches past the types on purpose - a field the class does not declare, a wrong-type argument for a runtime check, a stand-in passed as a `Control`, the fake `love` modules, `destroyerror` swapped through the globals table - it casts, with a comment. Tests write ownership with the extension (`x @ owner`, `f !@ x`) and assert the order of deaths, not only that they happened; a death by the collector is pinned with `collectgarbage("collect")` (twice when a weak table must clear), never with timing ([lifetime.md](lifetime.md)).

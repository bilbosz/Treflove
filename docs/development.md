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
require path, the build tools under `tools/`, and the editor support
(`.vscode/launch.lua`, the debugger script, and `editor/luals/`, the
language server plugin; "Editor Support" below); every module, test
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
the recipes cause everywhere are not reported: a local shadowing a global
*type* (every required class table and module table shares the name of its
type: `local Control: Control = require("controls.control")`, `local Consts
= require("app.consts")`; for a local interface in a test, also the "unused
type" tl then reports for it) and a super call (`Base.init(self)`)
([types.md](types.md), "Classes"). A local shadowing a global *value*
(`app`, `config`, `dump`) is reported. Success prints one line (`N modules
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

The `test-code.sh` script builds, checks that the language server plugin rewrites every `.tlt` and `.d.tl` file into valid Lua (`editor/luals/check.lua`, "Editor Support"), then prefers plain `luajit` (fast, headless) and falls back to `love . test` (runs the same suite inside LÖVE with the real `love.*` APIs). Both must pass; after a build, run the LÖVE one with:
```bash
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . test
```

Format the Lua files in place - `main.lua`, `conf.lua`, `tests/run.lua`, `tools/` and `.vscode/launch.lua` - with [lua-format](https://github.com/Koihik/LuaFormatter) (config in [.lua-format](../.lua-format); `build/`, `lib/` and the data file `server/save.lua` are left alone):
```bash
./format-code.sh [FILE.lua...]
```

Nothing formats the Teal sources: `lua-format` reads Lua only, and no formatter reads Teal with `@` and `!@`. The build and the lint do not check formatting.

Verify changes with `./build-code.sh`, `./test-code.sh`, `love . test`, `./lint-code.sh`, and by running the app (`./run.sh`; headless server: `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 5 love . server localhost 8080`; the client needs a window, so without a display run it under Xvfb: `xvfb-run -a love . client localhost 8080`).

## Editor Support

For VS Code; [.vscode/extensions.json](../.vscode/extensions.json) lists
the extensions, [.vscode/settings.json](../.vscode/settings.json) the
settings. Nothing under `.vscode/` is part of the app or the build. The
same shape as lua-lifetime's editor support
(`lib/lua-lifetime/editor/README.md`), adapted to Teal and LÖVE.

- **Reading `.tlt` and `.d.tl`.** Both are associated with Lua, as `.lt`
  is in lua-lifetime, and the Lua language server (`sumneko.lua`) reads
  them through [editor/luals/plugin.lua](../editor/luals/plugin.lua): the
  server parses Lua only, so the plugin's `OnSetText` rewrites a file
  into plain Lua of the same shape before the server parses it, as diffs
  the server maps every position back through, and `.tlt` files get
  completion, hover, go to definition and diagnostics with the types the
  fragments declare. The rewrite is lua-lifetime's for `.lt` (`@` and
  `!@` become `or`, a statement-form anchor `local _ = ...`, the
  `lifetime` header is inserted) plus the translation of Teal's types
  into the server's annotations (LuaCATS): the plugin parses the file
  with the transpiler's own parser and Teal dialect
  (`lib/lua-lifetime/lifetime/`), through a dialect that records every
  token the Teal dialect reads as a type and where each type stands,
  deletes them, and writes each type back as a comment the server reads
  ([editor/luals/cats.lua](../editor/luals/cats.lua) spells them): a
  local's type list becomes a `---@type` line before the statement, a
  function's parameters and returns `---@param` and `---@return` lines, a
  cast `--[[@as T]]`, and a type declaration (`global interface Client is
  App` and its fields, in a fragment or a module) a `---@class` with one
  `---@field` per field, an enum an `---@alias`, so that a `.d.tl` is
  read as the declarations it holds. Since the fragments name the whole
  (every class, `love.*` through `types/love.d.tl`, `lifetime.*` through
  the runtime's `init.d.tl`), a `self` in a method, a required class
  table and a field reached through them are typed. The rewrite is for
  analysis only and is never run; the plugin's header lists every rule.
  The server's checks are not the build's: a rewritten file turns off the
  server's checks of values against the annotations (every Teal type
  admits nil, a module's record is filled after `local m: M = {}`), it
  reports what is undefined, and `./build-code.sh` is the type checker.
  The tree is clean of the server's diagnostics, hints included (a
  parameter a body ignores is named `_x`, which
  `Lua.diagnostics.unusedLocalExclude` exempts).
  While a line is being typed the parser rejects the file and the server
  sees it raw, until the line is complete. The server resolves
  `require("a.b")` to `a/b.tlt` (`Lua.runtime.path`) and
  `require("lifetime")` to the runtime in the submodule, loaded as a
  library; `build/` and the rest of `lib/` are ignored. The first time
  the extension loads the plugin it asks whether to trust it.
  [editor/luals/check.lua](../editor/luals/check.lua) runs the rewrite
  over `.tlt` and `.d.tl` files and checks that each result compiles
  (`./test-code.sh` runs it over all of them; `--print` shows a rewrite).
  To run the server itself over the tree as the editor would:
  `lua-language-server --check . --configpath=FILE.json` with the
  settings of `.vscode/settings.json` as a `.luarc`-style file (the
  `Lua.` prefix dropped, `files.associations` included).
- **Formatting.** `koihik.vscode-lua-format` is the formatter of the Lua
  files, with the config in [.lua-format](../.lua-format) and the
  `lua-format` binary of [REQUIREMENTS.md](../REQUIREMENTS.md);
  `./format-code.sh` (the task "Format Lua files") formats them all. The
  Teal sources have no formatter ("Development Commands").
- **Building.** The task "Build" runs `./build-code.sh`; its problem
  matcher turns the `FILE:LINE:COL: message` lines into Problems entries,
  one per error, on the `.tlt` or `.d.tl` line.
- **Running.** "Launch" ([.vscode/launch.json](../.vscode/launch.json))
  runs `./run.sh` in a terminal through `discretegames.f5anything`: a
  build, then a server and a client, with no debugger.
- **Debugging.** The "Debug ..." configurations run under the "Local Lua
  Debugger" extension (`tomblind.local-lua-debugger-vscode`), each after
  the Build task: "Debug tests (LuaJIT)" is `luajit tests/run.lua`,
  "Debug tests (LÖVE)" is `love . test`, "Debug server" and "Debug
  client" are the two halves of `./run.sh` (start the server, then the
  client, as two sessions; they are not a compound, since two builds at
  once would race in `build/`). A breakpoint set in a `.tlt` file stops
  there, in a method called from a coroutine too; the stack and the
  tracebacks name the `.tlt` files and the locals shown are the generated
  chunk's. How: with the extension's variable set
  (`LOCAL_LUA_DEBUGGER_VSCODE=1`), `conf.lua` (the first chunk LÖVE runs)
  and `tests/run.lua` load [.vscode/launch.lua](../.vscode/launch.lua)
  before anything else. It starts the debugger, puts back the host's
  `error`, `assert`, `debug.traceback`, `coroutine.resume` and
  `coroutine.wrap` (the debugger's replacements stop at every raise,
  caught or not, which the lifetime runtime and the `_try_` constructors
  of `utils/media.tlt` do not survive; the script says so in full), and
  inserts a `package.loaders` searcher that loads each built module under
  the name of its source (`build/utils/tree.lua` as `@utils/tree.tlt`,
  the copied runtime as `lib/lua-lifetime/lifetime/init.lua`), which the
  build keeps line for line. Three limits follow: the debugger does not
  stop on an error (LÖVE's error handler or the test runner reports it,
  with its traceback, as always), `"breakInCoroutines"` must stay
  `false`, and the networking threads (`networking/detail/`, Lua states
  of their own started from `build/`) are not debugged. On Windows, the
  extension needs `t.console = false`, which `conf.lua` sets to `true`
  for the server; elsewhere the setting has no effect.

## Continuous Integration

GitHub Actions ([.github/workflows/ci.yml](../.github/workflows/ci.yml)) runs on every push; both jobs check out the submodules and build first:

- **Build, test, lint**: `./build-code.sh`, `./test-code.sh` (LuaJIT), `./lint-code.sh`
- **Test (LÖVE)**: `./build-code.sh`, then the same suite via `love . test`, headless with dummy SDL video/audio drivers

## Tests

The suite lives in [tests/](../tests/) and has no external dependencies. Its
modules are Teal, built with everything else into `build/tests/`:

- [tests/run.lua](../tests/run.lua) — entry point (Lua); lists test modules in `TEST_MODULES` (add new files there); requires the modules from `build/`, and under plain LuaJIT preloads a `socket` stub and the `utf8` shim
- [tests/lib/test.tlt](../tests/lib/test.tlt) — assertion framework: `test.suite(name)`, `test.case(name, fn)`, `assert_eq`, `assert_true/false`, `assert_near`, `assert_error`, `assert_deep_eq`
- [tests/lib/mocks.tlt](../tests/lib/mocks.tlt) — test doubles: `install_app()` (fake global `app`, typed `mocks.AppMock`, an `App` with a controllable clock and captured logs), `make_channel()`/`make_thread()` (in-memory LÖVE channel/thread stand-ins, `mocks.FakeChannel`/`mocks.FakeThread`), `make_keyboard()` (fake `love.keyboard` backend for `TextEventManager`), `ensure_love_data()` (real `love.data` under LÖVE, reversible fake under plain LuaJIT), `ensure_love_math()` (real `love.math` under LÖVE, an identity transform that ignores every other operation under plain LuaJIT, enough to construct and parent a `Control` or show a `Screen`), `ensure_love_login()` (real `love.data` hashing/encoding, `love.math` generator and `love.thread` channels under LÖVE; deterministic stand-ins under plain LuaJIT, for a login and a Connector)
- [tests/lib/utf8-shim.tlt](../tests/lib/utf8-shim.tlt) — pure-Lua `utf8.len/offset/codes`, preloaded by `tests/run.lua` under plain LuaJIT (LÖVE bundles the real `utf8`)
- Test files are named `test-<module>.tlt`, one per module under test

Conventions: pure calculation modules (`utils/aabb`, `utils/table`, `utils/class`, `app/arg-parser`) are tested with plain asserts; modules with runtime dependencies (event managers, `DeferManager`, `BackstackManager`, `Connection`/`RemoteProcedure`, `FormScreen`/`Input`, `Session` with a client and a server app back to back and a test double for the screen layer, [tests/test-session.tlt](../tests/test-session.tlt)) get mocks from `tests/lib/mocks.tlt` instead of the real `app`/LÖVE objects. Test code is typed like production code. Classes defined inside test files use a `Test` name prefix (e.g. `TestEchoRp`) so they can't collide with production class names, and are typed by a `local interface` in the test module (the class recipe of [types.md](types.md) works with a local interface; the build does not report the shadowing it causes). Types a test needs from a helper are nested in the helper's module record and named through it (`mocks.AppMock`). Where a test reaches past the types on purpose - a field the class does not declare, a wrong-type argument for a runtime check, a stand-in passed as a `Control`, the fake `love` modules, `destroyerror` swapped through the globals table - it casts, with a comment. Tests write ownership with the extension (`x @ owner`, `f !@ x`) and assert the order of deaths, not only that they happened; a death by the collector is pinned with `collectgarbage("collect")` (twice when a weak table must clear), never with timing ([lifetime.md](lifetime.md)).

# Development

After cloning, fetch the submodules (the LÖVE type annotations and the
lua-lifetime runtime):
```bash
git submodule update --init --recursive
```

## Running the Application

Run server only:
```bash
love . server localhost 8080
```

Run client only:
```bash
love . client localhost 8080
```

Run both server and client together:
```bash
./run.sh
```

## Development Commands

Format all Lua code (lua-format; the library and annotation submodules are
skipped):
```bash
./format-code.sh
```

Lint Lua code (luacheck):
```bash
./lint-code.sh [target_path]
```

Diagnose Lua code (lua-language-server; the results are JSON, empty when
clean):
```bash
./diagnose-code.sh [target_path]
```

Both scripts accept an optional `target_path` (a file or a directory) and
default to the whole project.

Run the automated test suite:
```bash
./test-code.sh
```

The script prefers plain `luajit` (fast, headless) and falls back to
`love . test` (the same suite inside LÖVE, with the real `love.*` APIs).
Both must pass.

The formatter, the linter and the language server each read their
configuration file at the repository root.

Verify changes with `./test-code.sh`, `./lint-code.sh`,
`./diagnose-code.sh`, and by running the app (`./run.sh`).

## Continuous Integration

GitHub Actions runs on every push:

- **Test, lint, diagnose**: the suite under LuaJIT, the linter, and the
  diagnostics (fails if the JSON is non-empty; the lua-language-server
  version is pinned in the workflow)
- **Test (LÖVE)**: the same suite via `love . test`, headless with dummy SDL
  video and audio drivers

## Tests

The suite has no external dependencies:

- The runner lists the test modules; a new test file is added to that list.
  Test files are named `test-<module>`, one per module under test.
- The assertion framework: `test.suite(name)`, `test.case(name, fn)`,
  `assert_eq`, `assert_true/false`, `assert_near`, `assert_error`,
  `assert_deep_eq`. Each case runs in protected mode, so one failure never
  stops the run.
- The test doubles: `install_app()` (a fake global `app` with a controllable
  clock and captured logs), `make_channel()`/`make_thread()` (in-memory LÖVE
  channel and thread stand-ins), `make_keyboard()` (a fake `love.keyboard`
  backend for the text event manager), `ensure_love_data()`,
  `ensure_love_math()`, `ensure_love_graphics()`, `ensure_love_thread()`
  (the real modules under LÖVE where they work without a window; reversible
  fakes under plain LuaJIT, so that real controls, screens and a connection
  manager can be built), `install_love_filesystem(files)` /
  `restore_love_filesystem()` (an in-memory file system over a table).
- A pure-Lua `utf8` shim is preloaded under plain LuaJIT (LÖVE bundles the
  real one).

Conventions: pure calculation modules (AABB, the table utilities, the class
system, the argument parser) are tested with plain asserts; modules with
runtime dependencies (event managers, the defer and backstack managers,
connections and remote procedures, the session, the screen manager, inputs,
the screens) get the test doubles instead of the real `app`/LÖVE objects.
Classes defined inside test files carry a `Test` name prefix (e.g.
`TestEchoRp`) so they cannot collide with production class names. A test of
a destruction asserts the whole order of the `release` calls and the
statement that caused them, as lua-lifetime's own suite does. The lifetimes
suite drives the whole ownership tree end to end: a client and a server in
one process over fake channels, the global `app` swapped per frame, through
connect, the auto-login, the game, back, the options, logout, a second
login, disconnect and the teardown `love.quit` runs; the collector is
stopped while a case logs a cascade, and each case tears both sides down at
its end, so a death by `reachable` never lands in a log.

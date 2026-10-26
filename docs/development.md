# Development

After cloning, fetch the submodules (the LÖVE and LuaSocket type
annotations and the lua-lifetime runtime):
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

Both take options after the port (a scenario to run, a console port, the
save directory identity, a fixture, a headless run); `run.sh` passes the
`join-game` scenario and a console port to each side. A scenario headless,
as a test with an exit code:
```bash
./scenario.sh join-game
```
See [scenarios-and-console.md](scenarios-and-console.md).

The console client as a LÖVE command, and the monitor window over one or
more consoles:
```bash
love . console 127.0.0.1 9090 'return app:get_time()'
love . monitor 127.0.0.1 client:9090,server:9091
```

## Debugging

The VS Code launch configurations (`.vscode/launch.json`, Run and Debug,
F5) run the program under the Local Lua Debugger extension
(`ismoh-games.second-local-lua-debugger-vscode`, the maintained
continuation of tomblind's, recommended by the workspace; the installed copy
is built from the fork `bilbosz/local-lua-debugger-vscode`, which adds the
`continued` event and the `breakInProtectedCalls` option):
`Client` (with the `join-game` scenario and the console ports `run.sh`
uses), `Client (login screen)` (no scenario), `Server`, the compound
`Server + Client` (both at once, one debug session each, stopped together),
`Scenario (headless)` (a scenario by name, asked for at launch, on the
offscreen driver against a server its tasks start and stop; breakpoints in
the scenario file work), `Monitor` (the window over the client's and the
server's consoles) and the test suite, `Tests (LuaJIT)` and
`Tests (LÖVE)`. Breakpoints, stepping and the inspection of locals work in
every module of the main Lua state. Each configuration sets
`breakInProtectedCalls` to false, the fork's default, so a caught error
never pauses. The compound's `stopAll` acts only on a manual stop, so the
Client's `postDebugTask`, `Stop the debugged server`, kills the server the
debugger launched (the one with the debugger's variable in its environment;
a server started from a shell stays) when the client's session ends, however
it ends. The task `Run Server + Client` runs `./run.sh` without a debugger.

The wiring: the extension sets `LOCAL_LUA_DEBUGGER_VSCODE` in the program's
environment and puts its `lldebugger` module on `LUA_PATH`; the entry point
(and the test runner, for the LuaJIT run) starts the debugger through the
debugger module (`app/debugger.lua`) before anything else, and without the
variable every function of that module is a no-op, so the program is
unchanged from the shell. An uncaught error, raised or a runtime one (an
index of `nil`, a bad argument to a LÖVE function), reaches the LÖVE error
handler, which prints it and asks the debugger to pause with the stack as it
is: the frame that raised the error and its locals are there to inspect, a
few frames below the handler; on continue the program exits, as it does
without the debugger. The extension pauses of its own accord only at an `error` or a failed
`assert` that nothing catches (its `breakInProtectedCalls` option, off: a
`pcall`, an `xpcall` or a `coroutine.resume` on the stack is a catch), and
under LÖVE everything runs inside the `xpcall` of the main loop, so there it
never does: the handler's request is how an error pauses.

Out of reach: the networking host threads (`networking/detail/`) run in
Lua states of their own, which the debugger does not see. The debugger talks
over the standard streams, so the LÖVE console (a window of its own, on
Windows) is switched off while it is attached.

Driving the debugger, by Claude through its debugmcp tools or by hand, and
running any Lua from an evaluation, a Watch or a breakpoint condition: the
`debug-live` skill, `.claude/skills/debug-live/SKILL.md`, which the debugmcp
tools ask for by name.

The console port is the other way into the live program: any Lua between
two frames, watches, a real pause, screenshots, from a shell and without
VS Code; see [scenarios-and-console.md](scenarios-and-console.md) and, for
Claude, the `live-console` skill (`.claude/skills/live-console/SKILL.md`).

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

The language server's configuration is strict, beyond its defaults: every
local, parameter, field and return must have a known type (`no-unknown`),
arguments are checked against parameter types, every signature is
documented, no global exists beyond the declared ones, and a table literal
returned or assigned as a class must have the class's shape. The command
line check loads the same constructor plugin the editor uses
(`.vscode/constructor_hints.lua`), so a `ClassName(...)` call is typed as an
instance on the command line and in CI as it is in the editor. The
annotation packages under `annotations/` (LÖVE, LuaSocket) and
lua-lifetime's own declarations type the external code; see
[type-annotations.md](type-annotations.md) for how the strict checks are
satisfied.

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
  channel and thread stand-ins; the thread records its starts and is ended
  by hand), `make_keyboard()` (a fake `love.keyboard`
  backend for the text event manager), `ensure_love_data()`,
  `ensure_love_math()`, `ensure_love_graphics()`, `ensure_love_thread()`
  (the real modules under LÖVE where they work without a window; reversible
  fakes under plain LuaJIT, so that real controls, screens and a connection
  manager can be built), `install_love_filesystem(files)` /
  `restore_love_filesystem()` (an in-memory file system over a table).
- A pure-Lua `utf8` shim is preloaded under plain LuaJIT (LÖVE bundles the
  real one).
- The main loop, the console, the console client and session, the
  console command, the monitor, the scenario driver and the runner are
  tested under fakes of their own: a `love.event` queue and timer, the
  LuaSocket stand-in of `tests/lib/console-socket.lua`, a fake main loop.

Conventions: pure calculation modules (AABB, the table utilities, the class
system, the tree, the argument parser) are tested with plain asserts; modules with
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

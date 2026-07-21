# Development

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

Format all Lua code (uses lua-format, excludes [annotations/](../annotations/)):
```bash
./format-code.sh
```

Lint Lua code (uses luacheck, config in [.luacheckrc](../.luacheckrc)):
```bash
./lint-code.sh [target_path]
```

The `lint-code.sh` script accepts an optional `target_path` (file or directory) and defaults to linting the entire project.

Diagnose all Lua code (uses lua-language-server):
```bash
./diagnose-code.sh [target_path]
```

The `diagnose-code.sh` script:
- Runs `lua-language-server` diagnostics and outputs results as JSON
- Accepts optional `target_path` argument to filter results (file or directory)
- Defaults to diagnosing the entire project if no target is specified
- Examples:
  - `./diagnose-code.sh` - diagnose entire project
  - `./diagnose-code.sh app/client.lua` - diagnose single file
  - `./diagnose-code.sh controls/` - diagnose directory

Run the automated test suite:
```bash
./test-code.sh
```

The `test-code.sh` script prefers plain `luajit` (fast, headless) and falls back to `love . test` (runs the same suite inside LÖVE with the real `love.*` APIs). Both must pass.

The project uses:
- `lua-format` for code formatting (config in [.lua-format](../.lua-format))
- `luacheck` for linting (config in [.luacheckrc](../.luacheckrc))
- `lua-language-server` for diagnosis report (config in [.luarc.json](../.luarc.json))

Verify changes with `./test-code.sh`, `./lint-code.sh`, `./diagnose-code.sh`, and by running the app (`./run.sh`).

## Tests

The suite lives in [tests/](../tests/) and has no external dependencies:

- [tests/run.lua](../tests/run.lua) — entry point; lists test modules in `TEST_MODULES` (add new files there)
- [tests/lib/test.lua](../tests/lib/test.lua) — assertion framework: `test.suite(name)`, `test.case(name, fn)`, `assert_eq`, `assert_true/false`, `assert_near`, `assert_error`, `assert_deep_eq`
- [tests/lib/mocks.lua](../tests/lib/mocks.lua) — test doubles: `install_app()` (fake global `app` with a controllable clock and captured logs), `make_channel()`/`make_thread()` (in-memory LÖVE channel/thread stand-ins), `ensure_love_data()` (real `love.data` under LÖVE, reversible fake under plain LuaJIT)
- Test files are named `test-<module>.lua`, one per module under test

Conventions: pure calculation modules (`utils/aabb.lua`, `utils/table.lua`, `utils/class.lua`, `app/arg-parser.lua`) are tested with plain asserts; modules with runtime dependencies (event managers, `DeferManager`, `BackstackManager`, `Connection`/`RemoteProcedure`) get mocks from `tests/lib/mocks.lua` instead of the real `app`/LÖVE objects. Classes defined inside test files use a `Test` name prefix (e.g. `TestEchoRp`) so they can't collide with production class names.

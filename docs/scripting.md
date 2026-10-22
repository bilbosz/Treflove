# Scripting (the sandbox)

The game master's rules, and later every player's scripts, run as untrusted
Lua inside the program: in an environment of their own, under a time and a
memory limit, stopped when they overrun either. The `scripting` folder holds
the two parts and nothing else is wired to them yet: the game data, the
sessions and the procedures that will feed scripts and act on their results
are the work of the scripting milestone (see `TODO.md`).

- `scripting/environment.lua`, the module `environment`: builds the globals
  a script sees
- `scripting/sandbox.lua`, the class `Sandbox`: runs source text or a
  script's function under the limits and reports what came of it

```lua
local Sandbox = require("scripting.sandbox")

local sandbox = Sandbox({world = world, roll = roll}, {time_limit = 0.5})
local result = sandbox:run(source, "rules.lua")
if not result.ok then
    app:log(result.failure, result.message)   -- "syntax" | "runtime" | "time" | "memory"
end
local on_turn = sandbox:get_environment().on_turn
if on_turn then
    result = sandbox:call(on_turn, token)      -- the same limits, the same report
end
```

## The environment

`environment.create(data, output)` returns a fresh globals table: a
whitelist of the standard library, then the entries of `data`. One sandbox
has one environment for its whole life, so the scripts of one sandbox share
their globals (a function defined by one run is called by the next, or by
the host through `call`), and two sandboxes share nothing.

What a script has:

| Globals | `assert`, `error`, `ipairs`, `next`, `pairs`, `pcall`, `rawequal`, `rawget`, `rawset`, `select`, `setmetatable`, `tonumber`, `tostring`, `type`, `unpack`, `_VERSION`, `_G` (the environment itself) |
| --- | --- |
| `string` | the text functions, `rep` capped at `Consts.SCRIPT_STRING_LIMIT` bytes of result |
| `table` | `concat`, `insert`, `maxn`, `remove`, `sort`: the standard ones, none of the program's extensions |
| `math` | everything but `randomseed` |
| `os` | `clock`, `difftime`, `time` |
| `print` | writes one line to the sandbox's output: the app's log, or the `output` option |
| `getmetatable` | of a table only; `nil` for anything else |
| `xpcall` | `pcall` with a handler; see below for why it is not the real one |

The library tables are copies, one set per environment: a script that
replaces `string.upper` changes its own `string` and nothing else. The
entries of `data` are not copied: a table the host passes is the one the
script reads and changes, and an entry replaces the standard one of its
name, so the host can hand a script its own `print` or `pairs`.

What a script has not, and why:

- `require`, `load`, `loadstring`, `dofile`, `loadfile`, `module`,
  `package`: code from outside the sandbox
- `io`, `os.execute`, `os.exit`, `os.remove`, `os.rename`, `os.getenv`,
  `os.tmpname`, `os.date` (a format it does not check), `os.setlocale`:
  the machine
- `debug`, `getfenv`, `setfenv`, `collectgarbage`, `newproxy`, `coroutine`:
  the program's own state, including the hook the sandbox runs on. A
  coroutine of the script's own would run hooked on LuaJIT (hooks are
  global there) but not under PUC Lua (per thread), so none are made
- `string.dump`: bytecode, which `run` refuses as a source too
- `math.randomseed`: the program's random generator is one for all
- the program's `table` extensions: `table.from_string` runs `loadstring`
  outside any sandbox
- `getmetatable` of a string: that metatable is one for every string of the
  program, so a script that reached it would reach the host

## The limits

`Sandbox(data, options)` takes `time_limit` (seconds of CPU time one `run`
or `call` may take, `Consts.SCRIPT_TIME_LIMIT` by default), `memory_limit`
(kilobytes the heap may grow during one, `Consts.SCRIPT_MEMORY_LIMIT`) and
`output` (where `print` writes). Both limits are checked by an instruction
count hook (`debug.sethook`, every `Consts.SCRIPT_HOOK_PERIOD` instructions)
while a script runs:

- **Time**: `os.clock()` since the run began. A script that overruns it
  fails with `Sandbox.Failure.TIME`.
- **Memory**: `collectgarbage("count")` since the run began; when it is
  over the limit, a full collection runs first, so garbage the script
  already dropped does not count. `Sandbox.Failure.MEMORY`.

How an interruption works, and what it rests on:

- **The script's own code never runs compiled.** LuaJIT runs no hook inside
  a compiled trace, so a hot loop would never be interrupted; `run` marks
  the loaded chunk and every function in it with `jit.off(chunk, true)`.
  That is the performance price of the sandbox, paid by the script alone.
- **Nothing a script does keeps it running once interrupted.** After the
  first interruption the hook fires on every instruction and raises again,
  so a `pcall` that caught the first error, or a `return pcall(...)` that
  hid it in a tail call, is followed by the next; the guard reports the
  limit whatever the chunk returned. The hook stands down when the
  interruption has unwound to the guard's own stack frame, which it
  recognizes by its depth, so a run nested in a host function (a script
  that calls into another sandbox) is stopped alone and the outer script
  goes on.
- **`xpcall` is `pcall` with a handler.** Inside the real `xpcall` the
  handler runs with the hook silent on LuaJIT, so a handler could loop
  past every limit.
- **One call into C runs to its end.** The hook runs between Lua
  instructions, so a single library call that takes long is not
  interrupted: `string.rep` is capped for that reason, by the environment's
  own `rep` and, while a script runs, through the method syntax too (the
  string metatable indexes the sandbox's `string` for the duration of the
  run). A pattern that backtracks exponentially (`("a?"):rep(n) ..
  ("a"):rep(n)` against `("a"):rep(n)`) is the known hole: it ends, but
  not when the limit says. Capping the pattern length does not bound it,
  so it is left to the host's choice of who may script.
- **The hook that was set before** (a debugger's) is replaced for the run
  and put back after it, so a script is not steppable, but the program
  around it is.

A failed run leaves the sandbox usable: the next `run` or `call` starts a
fresh budget. A `Sandbox` has nothing to release; a holder anchors it as it
would any plain object.

## Rules for the host side, when the wiring comes

- **A script's function is called through `sandbox:call`**, never
  directly: called any other way it runs under no limit, compiled or not.
- **A host function given to a script can be interrupted between any two
  of its instructions**, like the script's own code: it unwinds with the
  interruption. Keep such functions short, and make their change to the
  game state last, or atomic, so an interruption leaves nothing half done.
  A host function that loops long is not stopped by the hook when it runs
  compiled; one that must loop is marked `jit.off` or bounded by its
  arguments.
- **What the host passes in `data` is what the script may read and
  change.** A script cannot tell a private field from a public one, nor
  lua-lifetime's state field from the rest (`pairs` is the real one):
  expose game data through copies or proxies, not the live tables.
- `result.values` are the chunk's or the function's returns, with their
  positions (a `nil` in the middle stays in place); `result.message` is
  the error as text, prefixed by the chunk name and line for a syntax or a
  runtime error (`rules.lua:3: ...`), or the limit for an interruption.

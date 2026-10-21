---
name: debug-live
description: Drive the running LÖVE app or the test suite under the VS Code debugger (the debugmcp tools over the Local Lua Debugger) on your own - start a configuration, break, step, and run arbitrary Lua inside a paused frame, a Watch or a breakpoint condition to read or change anything at runtime. Use it for a runtime question, a crash, a wrong value, a hang, or to see a change working in the live app instead of reasoning about it; the debugmcp tools ask for this skill by name.
---

# Debug Live

Treflove runs under `tomblind.local-lua-debugger-vscode` (lldebugger), wired
by `app/debugger.lua` (see `docs/development.md`, "Debugging").
The debugmcp tools (`mcp__debugmcp__*`) drive the VS Code session; the same
tricks work by hand in the Debug Console, the Watch panel and a conditional
breakpoint. The runtime is LuaJIT, so `setfenv`, `getfenv` and `loadstring`
exist. Everything below was verified in this project.

## The session

- Launch configurations (`.vscode/launch.json`): `Client`, `Server`,
  `Tests (LuaJIT)`, `Tests (LÖVE)`, and the compound `Server + Client`.
  `start_debugging` takes `configurationName` plus `fileFullPath` (`main.lua`)
  and `workingDirectory` (the repository). debugmcp controls one session; to
  debug the client against a server, run the server from a shell
  (`love . server localhost 8080`).
- `get_debug_status` first, always: the user may already be paused somewhere.
  With `waitForPauseSeconds` it blocks until a breakpoint hits. Leave a
  session the user paused where it was: read and evaluate, do not continue or
  step it without saying so.
- Breakpoints: `add_breakpoint(fileFullPath, line, condition)`,
  `list_breakpoints`, `remove_breakpoint`, `clear_all_breakpoints`. Stepping:
  `continue_execution`, `step_over`, `step_into`, `step_out`. Inspection:
  `list_variable_names`, `get_variables_values`, `evaluate_expression`.
- Not available with this adapter: `pause_execution` (a running program cannot
  be interrupted; set a conditional breakpoint on a hot line such as the first
  line of `love.update` in `app/app.lua` instead), `add_logpoint` and hit
  counts (use the condition trick below), and breakpoints in the networking
  thread scripts (`networking/detail/`, Lua states of their own).
- Quirks: a breakpoint on a multi-line statement hits twice; the debugger
  pauses once by itself at the first `error` or failed `assert` after a start,
  caught or not (continue past it); an uncaught error pauses inside the error
  handler, and the raising frame is a few frames below (`app/debugger.lua`,
  `app/app.lua`, boot.lua, then the code).

## Run any code: statements inside an expression

The adapter sends one line, `eval <expression>`, and prepends `return`. So an
evaluation, a Watch and a breakpoint condition each take exactly one
expression on one line. A function expression called at once turns that into
any code:

```lua
(function() local n = 0; for _ in pairs(params) do n = n + 1 end; return "fields: " .. n end)()
```

- One line only: a newline splits the command and desynchronizes the
  protocol. Separate statements with `;`. No `--` line comment (it eats the
  rest); `--[[ ]]` is fine.
- The chunk's environment is a proxy of the selected frame: its locals and
  upvalues by name (`self`, `params`, `dt`, ...), then the function's globals
  (`app`, `require`, `print`, the declared globals). Reads and writes work;
  an assignment to a local or an upvalue is copied back into the frame when
  the chunk succeeds, so `params = {...}` or `self._field = 42` really change
  the running program.
- Return a string you compose with `tostring`, or a table to expand in the
  UI. `table.to_string(t)` (the project's serializer) and
  `Utils.dump_controls(app.root)` (`require("utils.utils")`) give whole
  structures as one string.
- Everything is reachable from `app`: `app.session`, `app.screen_manager`,
  `app.data`, `app.root`, the managers; and any module with `require`.

As a breakpoint condition, the same expression runs on every pass of the
line, in that frame, and the breakpoint pauses only when it returns a truthy
value. That makes it a logpoint with code, a counter, or a trap:

```lua
(function() _G.n = (_G.n or 0) + 1; print("tick " .. _G.n .. " dt=" .. dt); return false end)()
(function() _G.n = (_G.n or 0) + 1; return _G.n == 3 end)()
(function() return self == app.session and msg.kind == "login" end)()
```

Verified: a condition with a `print` on `love.update` ran about 3800 times in
five seconds without pausing, and paused exactly once when it returned true.
Globals (`_G.n`, `_G.probe = {}`) carry state between passes; read them later
with an evaluation. A Watch is evaluated at every pause and on every refresh
of the panel, so its side effects repeat: keep Watches read-only.

## Guard the code with pcall / xpcall

- A condition that fails is silent: a syntax error or a runtime error in it
  makes the breakpoint never pause and reports nothing. Try the chunk as an
  evaluation at a pause first, then wrap the risky part:

  ```lua
  (function() local ok, r = pcall(function() return msg.body.user.name end); if not ok then print("probe: " .. tostring(r)) end; return ok and r == "adam" end)()
  ```

- Do not raise in a probe: `error` and `assert` are overridden by the debugger
  and can pause with an "exception" before `pcall` catches them (the first time
  after a start). Test and return a status instead.
- In an evaluation at a pause, a runtime error fails the evaluation (it shows
  as `[error] ...` in the Debug Console) and nothing is written back to the
  frame; inside `pcall` the chunk succeeds, the work done so far stands, and
  the message is in your result. `error` inside `pcall` does not pause here,
  since the debugger is already paused. `xpcall(f, debug.traceback)` gives the
  location of the failure.

## Load a file

For more than a line, write a script in the scratchpad and run it from the
expression:

```lua
assert(loadfile("/abs/path/probe.lua"))()
```

It runs in the main Lua state, inside the paused program, with the global
environment: `app`, `require("app.consts")`, `print`; a `return` value is
displayed. Whatever it changes stays changed (fields, globals,
`package.loaded["x"] = nil; require("x")` reloads a module, though existing
references keep the old one). `loadstring(code)` runs code built as a string.

## Give a file the frame's variables

`getfenv()` inside the expression is the frame proxy described above. Hand it
to the loaded chunk and the file sees the frame's locals and upvalues as
globals, and can assign them (written back when the evaluation succeeds):

```lua
setfenv(assert(loadfile("/abs/path/probe.lua")), getfenv())()
```

with, in the file, plain `self`, `params`, `dt`. The proxy has no raw keys
(`rawget` and `pairs` see nothing): list the frame's names with
`list_variable_names`, and keep `local x = require(...)` in the file for what
is not a global (`lifetime`, `Utils`).

## Without VS Code: the debugger from a shell

When no session is open, or for a headless check, run the program with the
extension's environment and feed it the debugger's commands on stdin; the
server is headless on Linux, the client opens a window, the suite is
`luajit tests/run.lua` or `love . test`:

```bash
EXT=$HOME/.vscode/extensions/tomblind.local-lua-debugger-vscode-0.3.3
export LOCAL_LUA_DEBUGGER_VSCODE=1 LOCAL_LUA_DEBUGGER_FILEPATH=$EXT/debugger/lldebugger.lua \
       LOCAL_LUA_DEBUGGER_SCRIPT_ROOTS=$PWD LUA_PATH="$EXT/debugger/?.lua;;"
timeout 8 love . server localhost 8089 < commands.txt > out.txt 2>&1
```

Commands, one per line: `break set /abs/file.lua:N [condition]`,
`break delete /abs/file.lua:N`, `cont`, `step`, `stepin`, `stepout`, `stack`,
`frame N`, `locals`, `ups`, `eval <expression>`, `exec <statement>`, `quit`.
The program pauses right after the start and reads commands until `cont`;
each later pause reads the next ones; end of input at a pause exits the
process. The output interleaves the program's own with the debugger's
messages, `@lldbg|{...}|lldbg@`, pretty-printed over several lines. Capture
to a file and summarize afterwards: `timeout` in a pipeline kills the
summarizer too.

## A session, end to end

1. `get_debug_status`. No session: start the configuration the question
   needs, or ask the user to press F5 when the client's window and their
   interaction are part of it.
2. Put a breakpoint where the question is, with a condition that narrows it
   (an identity, a field value, a counter), and let the program reach it:
   `get_debug_status` with `waitForPauseSeconds`.
3. At the pause: `list_variable_names`, then evaluations for the facts;
   change state to test a hypothesis; step to watch it propagate.
4. Clean up: `clear_all_breakpoints`, remove probe globals, and leave the
   session as the user had it.

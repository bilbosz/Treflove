---
name: live-console
description: Run Treflove headless and drive it from the shell - a scenario end to end (./scenario.sh <name>, exit code and logs), or the live client or server through its console port (luajit tools/console.lua <port> '<lua>'), watching values as they change, pausing the loop, taking screenshots to look at. Use it to see a change working, to reproduce a reported failure by scenario name, or for any runtime question that does not need a breakpoint; for stepping and a frame's locals use debug-live instead.
---

# Live console and scenarios

The design and the vocabulary: `docs/scenarios-and-console.md`. This file
is the practice: what to type, what to expect, what bites.

## A scenario, headless

```bash
./scenario.sh join-game                 # exit 0: passed; exit 1: failed; the logs are printed at the end
./scenario.sh assets-workspace
./scenario.sh logout
ls scenarios/                           # the names
```

The script starts a server (headless, its own identity `treflove-scenario`,
the fixture `scenarios/fixtures/basic`, console 9091) and the client
(offscreen, console 9090, the scenario) and kills the server at the end.
Logs: `/tmp/treflove-scenario/<name>/client.log` and `server.log`. A
failure logs `scenario <name>: failed: <error>` with the traceback and the
control dump (`Utils.dump_controls`), which is the screen as text; read
it before reaching for a screenshot.

A multi-client scenario (`two-players`, `shared-store`, `peer-logout`)
returns a table with `peers`; the script starts the peers itself, and the
lead drives them with `driver:client(name, chunk)` and `:wait()`; a peer's
failure comes back with its name, and each peer has its own log next to
the client's.

To write one: copy the closest file under `scenarios/`, keep the shared
steps from `scenarios/lib/steps.lua`, find controls by class and caption
(`driver:click("TextButton", "Join Game")`), never by coordinates, wait
with `wait_screen` or `wait_for` (wall-clock timeouts, default 10 s),
jump app time with `advance(seconds)`, check the server with
`driver:server("return ...")`. The driver's API is the class annotation in
`app/scenario-driver.lua`.

## The console, from the shell

The client of `run.sh` and the launch configurations listens on 9090, the
server on 9091 (localhost only; `--console <port>` on the command line).

```bash
luajit tools/console.lua 9090 'return get_class_name_of(app.screen_manager:get_screen())'
luajit tools/console.lua 9090 'return table.to_string(app.data.game)'
luajit tools/console.lua 9090 'return require("utils.utils").dump_controls(app.root)'
luajit tools/console.lua 9090 'return screenshot("now.png")'      # the path; Read it once the frame is drawn
luajit tools/console.lua 9090 'pause()'                            # the update loop stops; the window still draws
luajit tools/console.lua 9090 'frames(1)'                          # one update
luajit tools/console.lua 9090 'resume()'
luajit tools/console.lua 9090 'scenario("assets-workspace")'      # on the live client, which stays at the end
luajit tools/console.lua 9090 < /abs/path/probe.lua                # a file as the chunk
```

- A chunk is any Lua, multi-line, run between two frames with `_G` in
  scope (`app`, `require`, the globals). Return what you want to see;
  tables come back serialized.
- An error comes back as `error` with the traceback and exit code 1 from
  the CLI; nothing in the program changes.
- Watches, in the background, to a file you read later:

```bash
luajit tools/console.lua 9090 --watch 'get_class_name_of(app.screen_manager:get_screen())' > /tmp/claude-1000/.../screen.log &
luajit tools/console.lua 9090 --follow 'log(true)' > /tmp/claude-1000/.../app.log &
```

  One line per change: name, frame, app time, value. A watch runs every
  frame: keep its expression cheap and read-only.

- The host threads of the networking are separate Lua states: the
  console does not reach them (nor does the debugger).

## Pitfalls

- The console is serviced once per main loop iteration: a program the
  debugger holds paused does not answer until it continues.
- `screenshot` returns before the file exists; the frame has to be drawn
  first. Headless, frames are fast; windowed, wait a moment.
- A scenario run with `--windowed` opens a window on the user's screen:
  only when they asked for it.
- Never point a client at port 8080 from a scenario: the user's own server
  may hold it; `scenario.sh` uses its own port and identity.

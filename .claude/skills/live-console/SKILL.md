---
name: live-console
description: Inspect and steer a running Treflove client or server from the shell through its console port - run any Lua inside the live program between two frames (luajit tools/console.lua <port> '<lua>' or love . console), watch values as they change, stream the log, pause and step the main loop, take screenshots to read, start a scenario on the live program, and drive the monitor window. Use it for any runtime question that needs no breakpoint ("what screen is it on", "what does the server hold", "why does this value change", "show me"), to reproduce a failure on a live program, or when the user mentions the console, a watch, the monitor or the ports 9090 and 9091. For writing scenarios use scenario-authoring, for a headless run from scratch headless-smoke, for stepping and a frame's locals debug-live.
---

# The console, from the shell

A client or server started with `--console <port>` runs any Lua sent to
that port between two frames, with the program's globals in scope, and
answers with the results. `run.sh` and the `Client` and `Server` launch
configurations open 9090 on the client and 9091 on the server. The
design: `docs/scenarios-and-console.md`, "The console".

```bash
luajit tools/console.lua 9090 'return get_class_name_of(app.screen_manager:get_screen())'
luajit tools/console.lua 9090 'return app.session:get_user(), app:get_time()'      # several values, tab-separated
luajit tools/console.lua 9091 'return table.to_string(app.data.game)'               # a table, serialized
luajit tools/console.lua 9090 'return require("utils.utils").dump_controls(app.root)'   # the screen as a tree
luajit tools/console.lua 9090 'app.session:logout()'                                 # a change; no return value
luajit tools/console.lua 9090 < /abs/path/probe.lua                                  # a longer chunk from a file
love . console 127.0.0.1 9090 'return 1 + 1'                                         # the same under LÖVE; slower to start
```

Return what you want to see; an error comes back with its traceback and
exit code 1, and nothing in the program changes. Exit 2 is a refused
connection or a timeout: the program is not up, or holds another port.

The chunk's environment adds a few functions:

```bash
luajit tools/console.lua 9090 --watch 'get_class_name_of(app.screen_manager:get_screen())' > $S/screen.log &   # one line per change
luajit tools/console.lua 9090 --follow 'log(true)' > $S/app.log &                                                # the log, live
luajit tools/console.lua 9090 'pause()'              # the update loop stops at a frame boundary; events and draw go on
luajit tools/console.lua 9090 'frames(1)'            # one update while paused
luajit tools/console.lua 9090 'resume()'
luajit tools/console.lua 9090 'return screenshot("now.png")'    # the path, under the save directory; Read it after the frame
luajit tools/console.lua 9090 'scenario("assets-workspace")'    # a scenario on the live client, which stays at its end
luajit tools/console.lua 9090 'run([[ steps.join_game(driver) return app:get_time() ]])'   # a scenario chunk; replies when it ends
luajit tools/console.lua 9090 'quit()'
```

- A watch line is `name`, frame, app time, value; the first value and
  every change. A watch runs every frame: keep it cheap and read-only.
  Background the watch and the follow to files in the scratchpad and read
  them later; the options go before or after the port.
- `run` is how a peer client is driven by a scenario: the chunk runs as a
  scenario with `driver` and `steps` in scope, and the reply (its return
  values, or the error with the traceback) comes when it has finished; a
  one-line `return` is a question answered at once.
- `scenario(name)` and `run` leave the program running at the end, so a
  failure can be inspected where it happened: the screen, the dump, a
  screenshot, the session.
- `pause` is a real pause of the updates; a quit while paused resumes
  first. A program the debugger holds paused does not answer until it
  continues; both can be attached at once.

## The monitor

`love . monitor 127.0.0.1 client:9090,server:9091` is the user's window
over the consoles: a button per target with its state, the selected
target's watches with live values, its log, and a line that evaluates a
chunk on it or adds a watch after `=`. It reconnects by itself and shows
the watches a target already holds. To check it headless, give it a
console of its own and drive that: `SDL_VIDEODRIVER=offscreen
SDL_AUDIODRIVER=dummy love . monitor 127.0.0.1 client:9190,server:9191
--headless --console 9194`, then `screenshot("m.png")` through 9194 and
`love.event.push("textinput", "return 1")` with a `keypressed`
`"return"` to type into its line.

## Pitfalls

- The user's own client and server may be up on 9090 and 9091: a chunk
  sent there acts on their program and their data. Ask a read-only
  question first (`return app.params.identity`) when unsure which program
  answers, and start pairs of your own on other ports (headless-smoke).
- `screenshot` replies before the file exists; the frame has to be drawn
  first. Headless frames are fast; a window started from this shell draws
  once a second.
- The console is serviced once per main loop iteration, so a chunk that
  blocks (a long loop, a blocking socket) stalls the program for its
  duration.
- The host threads of the networking are separate Lua states, out of
  reach of the console and of the debugger.
- `sleep` is blocked in the harness: wait with
  `luajit -e "require('socket').sleep(0.5)"` or poll a console question.

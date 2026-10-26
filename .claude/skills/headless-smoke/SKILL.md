---
name: headless-smoke
description: Run the real Treflove client and server without a window to see a change working - start both headless on free ports and identities of their own, drive the client to the state in question (a scenario, or Lua through the console), take a screenshot and read it, compare before and after, tear down by PID. Use it after any change to the UI, the screens, the controls, the game page, the networking or the startup, whenever the user asks to "run it", "check it in the app", "see if it works", "take a screenshot", or to confirm a change beyond the test suite; also when a test passes but the behavior in the real program is in doubt. The global run skill defers to this one for this project.
---

# A headless check of the real program

The test suite proves the units; this proves the program. SDL's
`offscreen` driver gives LÖVE a real OpenGL window that is not on screen,
so the client renders exactly as in a window and a screenshot is the
truth. The pieces: `./scenario.sh` for a flow that exists as a scenario
(scenario-authoring), the console for anything else (live-console), and
the pair scripts here for the boilerplate of starting and stopping.

## The run

```bash
S=.claude/skills/headless-smoke/scripts
$S/start-pair.sh check                                  # a server and an offscreen client, consoles 9191 and 9190
luajit tools/console.lua 9190 'scenario("join-game")'   # drive to the state: a scenario on the live client...
luajit tools/console.lua 9190 'app.session:login("adam", "krause")'   # ...or Lua, step by step
luajit tools/console.lua 9190 'return get_class_name_of(app.screen_manager:get_screen())'
luajit tools/console.lua 9190 'return require("utils.utils").dump_controls(app.root)'    # the screen as text
luajit tools/console.lua 9190 'return screenshot("check.png")'                           # the path; Read it
$S/stop-pair.sh check                                   # by PID; prints the log tails
```

`start-pair.sh <tag>` refuses a console port that is in use and a tag
that is still running; `--port`, `--server-console`, `--client-console`
pick others, `--scenario <name>` starts the client with a scenario,
`--fixture <dir>` another fixture, `--windowed` a window on the user's
screen (only when they asked). The identities are `smoke-<tag>-server`
and `smoke-<tag>-client`, so the user's own save directory is never
touched; the logs are under `/tmp/treflove-smoke/<tag>/`.

Wait for a state with a short loop over a console question, never with a
fixed sleep, and never with `sleep` itself, which the harness blocks:

```bash
for i in $(seq 20); do [ "$(luajit tools/console.lua 9190 'return app.scenario_runner:is_running()')" = false ] && break; luajit -e "require('socket').sleep(0.25)"; done
```

A screenshot is taken at the end of the frame the chunk runs in: ask for
it after the state is reached, and read the file once the reply names it
(headless frames are fast). Read the screenshot with the Read tool and say
what it shows; the control dump is the screen as a tree when pixels are
not the question.

## Before and after

For a change whose effect is visual, take the same screenshot on
`master` first: a detached worktree of the committed tree
(`git worktree add --detach /tmp/treflove-wt/before master`, submodules
cloned from the checkout) started with `start-pair.sh before --port 8291
--server-console 9291 --client-console 9290` from that worktree, the same
steps, the same screenshot name under its own identity. Keep both files
and compare them side by side in the report. Remove the worktree after.

## Checklist

- Ports: the user's own client and server, from `run.sh` or F5, listen on
  8080, 9090 and 9091; a scenario run on 8181 and 9090/9091. The scripts
  refuse a taken console port; pick others rather than stopping anything.
  `ss -tlnp` and `ss -ulnp` show what is held.
- Teardown by PID, which the scripts keep; never `pkill -f` with a
  pattern that also matches the shell running the chain. `pgrep -x love`
  at the end lists what is left; the user's processes stay.
- A background process in a Bash tool call goes on a line of its own: an
  `&` after an `&&` chain backgrounds the whole chain, and nothing set in
  it reaches the foreground.
- A process `timeout` kills never flushes its buffered stdout; the
  scenario runner and the console flush their lines, a temporary print
  must `io.stdout:flush()` itself.
- A windowed client started from a shell on this machine presents at one
  frame per second (adaptive vsync under XWayland); headless is unaffected,
  so measure frame rates headless or compare with `master` before calling
  a slowness a regression.
- The host threads of the networking are separate Lua states: nothing in
  them is reachable from the console; their logs are blacklisted by
  default (`LOGGER_NAME_BLACKLIST`).

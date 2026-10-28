# Scenarios, the headless run and the console

Three tools for seeing the program run without a hand on the mouse: a
scenario drives the client through its UI from a Lua file, headless or in
a window; the headless run gives the client a real OpenGL window that is
not on screen; the console is a localhost port that runs Lua inside the
live program, watches values and pauses the loop. They share the command
line and the project's own main loop. The practice, for Claude, is in
three skills under `.claude/skills/`: `scenario-authoring` (writing and
running scenarios, the fixture), `live-console` (the console and the
monitor) and `headless-smoke` (a headless check of a change).

## The command line

```
love . <client|server> <address> <port> [options]
love . console <address> <port> [chunk] [--follow] [--watch <expr>]
love . monitor <address> <name>:<port>[,<name>:<port>...] [--headless] [--console <port>]
  --scenario <name>        client only: run scenarios/<name>.lua at start
  --console <port>         the console port on 127.0.0.1
  --server-console <port>  client only: the server's console port, for the
                           scenario driver's server(...) calls
  --identity <name>        the LÖVE save directory identity
  --fixture <path>         server only, with --identity: a directory of the
                           source tree whose copy replaces the server root
                           at load (it empties the root)
  --headless               fixed frame delta, no sleep, no vsync
  --peers <name>:<port>,.. client only: the console ports of the peer clients a
                           scenario drives
```

An option on the wrong side, an unknown option, a missing value (a value
starting with `--` counts as missing), a repeated one or `--fixture`
without `--identity` show the usage message, as a bad address does, and
the program exits with code 2. The save directory
(`~/.local/share/love/<identity>/` on Linux) holds the server's state
under its root `s` (`s/accounts.lua`, `s/games/<id>/save.lua` and
`s/games/<id>/assets/`) and the client's copies under `c`
(`c/games/<id>/assets/`); the default identity is the name of the game folder, so a run
from another checkout writes elsewhere, and a scenario run names its own
identity so the user's data stays untouched.

## The main loop

`MainLoop` (`app/main-loop.lua`) is the project's `love.run`, installed by
the app with its callbacks. One iteration: the events (a quit ends the
loop through `love.quit` with its exit code), then `app.service_event` (no
arguments, paused or not), then the update with its delta, then the draw,
then a millisecond of sleep. The delta is the real one from `love.timer`
or, headless, `MainLoop.FIXED_DT` (one sixtieth), plus whatever `skip`
added since the last update; the app's clock (`app:get_time()`) is the sum
of the deltas from zero, so a headless run advances it by exactly what it
asked for, and a skip of a minute passes a minute of notifications and
deferred calls in one frame. The timer is stepped every iteration, so a
pause does not pile up into one huge delta. `pause` stops the updates at
the next frame boundary while the events, the service event and the draw
go on; `step(n)` runs n updates while paused; `resume` continues. A quit
(`app:quit(exit_code)`) is honored by the next update, so whoever quits a
paused loop resumes it. The host threads of the networking live in real
time and know nothing of this.

## The headless run

SDL's `offscreen` video driver gives LÖVE a real OpenGL window that is not
on screen: fonts, images, draws and `love.graphics.captureScreenshot` are
the production ones, so the layout is byte for byte the windowed one. The
`dummy` driver cannot create an OpenGL context, which is why the test run
(`love . test`) has no window at all.

```bash
SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy love . client localhost 8181 --headless ...
```

`--headless` goes with it: the loop runs without sleeping, at a fixed
delta, with vsync off. The server needs neither: on Linux it has no
window, and its loop keeps real time.

## Scenarios

A scenario is a file `scenarios/<name>.lua` returning a function over a
`ScenarioDriver` (`app/scenario-driver.lua`). It reads top to bottom: wait
for a screen, find a button by its caption, click it, type, expect. The
runner (`ScenarioRunner`, `app/scenario-runner.lua`, created by the client
for `--scenario`) runs it as a coroutine resumed once per update; every
wait yields frames. Input goes through `love.event.push`, so it is
dispatched by the loop's poll through the same callbacks as real input.
Targets are found, never aimed at: `find(class_name, text, index)` walks
the root's visible, enabled controls in draw order and `click` presses the
center of the match's bounding box.

```lua
---@param driver ScenarioDriver
return function(driver)
    driver:wait_screen("LoginScreen")
    driver:click("TextInput")
    driver:type("adam")
    driver:click("TextInput", nil, 2)
    driver:type("krause")
    driver:click("TextButton", "Sign In")
    driver:wait_screen("UserMenuScreen")
    driver:click("TextButton", "Games")
    driver:wait_screen("GamesMenuScreen")
    driver:click("TextButton", "Join")
    driver:wait_screen("JoinGameScreen")
    driver:click("TextButton", "Meadow")
    local game = driver:wait_screen("GameScreen")
    driver:expect(#game:get_page():get_tokens() == 2, "two tokens on the page")
end
```

- `wait_for(predicate, timeout, what)` and `wait_screen(class_name)` time
  out in wall-clock seconds (`SCENARIO_WAIT_TIMEOUT`), so a run that is
  fast or slow passes alike; `advance(seconds)` jumps the app's clock
  (a notification's duration, a deferred call) in one frame.
- `key(key)` presses and releases a key in one frame; `key_down(key)` and
  `key_up(key)` push one event each, so a modifier is held across the
  keys between them (`key_down("lctrl")`, `key("a")`, `key_up("lctrl")`):
  the keyboard manager tracks the pressed keys from the events, since the
  hardware state a pushed event never changes is what `love.keyboard`
  reports.
- `server(chunk)` evaluates Lua on the server through its console
  (`--server-console`) and returns the reply: a scenario checks the
  server's state or nudges its clock from the client side.
- `screenshot(name)` saves to the save directory and returns the path;
  the name carries the extension LÖVE encodes by (`old-town.png`).
- The outcome is logged (`scenario <name>: passed` or `failed: <error>`
  with the traceback and the control dump). The scenario given on the
  command line, headless, then quits the client with exit code 0 or 1;
  one started through the console, or any in a window, leaves the
  program where it is, so a failing scenario is picked up where it
  failed, and a passing one is a bookmark: the app at the state the
  scenario reached.

The shared steps live in `scenarios/lib/steps.lua`. The scenarios:
`join-game` (the login, the games list and the game), `assets-workspace`
(the workspace from the game, its listing against the game's store,
back), `logout` (out and in again), `sign-up` (an account created from
the login screen, signed in at once, out and in again), `new-game` (a
game created from Games and entered, its template page and token,
listed afterwards), `fresh-start` (what a user does on a server
that holds nothing: an account signed up, a game created and entered,
listed afterwards; it reads nothing of the fixture, so it passes on an
empty root too) and `old-town` (the Old Town world of the fixture of the
same name: its page, its four tokens, its store; it ends in the game, so
`./scenario.sh old-town --windowed` is the developer's way into a game
with content).

### Several clients

A scenario that drives other clients returns a table instead of a
function: `peers` names them, `run` is the scenario. The script starts one
client per peer, with its own save directory identity and a console port,
and hands their ports to the lead with `--peers`. The lead sends a peer a
chunk of scenario code with `driver:client(name, chunk)`; the peer runs it
as a scenario of its own, with `driver` and `steps` in scope, through the
console verb `run`, whose reply comes only when the chunk's coroutine has
finished. The call returns a handle at once, so the lead goes on; its
`wait` yields frames until the peer is done and raises with the peer's name
when the peer's run failed. A chunk that only returns a value is a run that
ends at once, so one primitive serves both steps and questions.

Underneath: the runner's `start_function` runs any function as a scenario
and calls an `on_end` handler with the result (its `traceback` set for a
failed run) and the values a passing run returned; the console client's
`request_async` sends without waiting and `poll` completes the pending
requests in order as their replies arrive, which is what the handle polls
once per frame.

```lua
local steps = require("scenarios.lib.steps")

return {
    peers = {"bob"},
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", [[
            steps.join_game(driver, "piotr", "secret")
        ]])
        steps.join_game(driver)
        bob:wait()
        local seen = driver:client("bob", [[ return driver:try_find("Token", "Smaug") ~= nil ]]):wait()
        driver:expect(seen == "false", "bob reads only the tokens he owns")
    end
}
```

What the server can show across clients today, and the scenarios that
show it: `two-players` (each player's game filtered by their grants, two
logged-in sessions on the server), `shared-store` (a folder made by one
client listed by the other) and `peer-logout` (one peer out, the other
still in the game) and `move-token` (the first slice of game state
synchronization, `TODO.md` milestone 2: adam drags Bilbo, piotr's client
shows it at the new position, the server's save holds it, and a change
piotr's client sends past its own gate, `Session:update_token` through the
console, is refused by the server with the reason notified) and
`create-token` (the second slice: adam creates a token from the game's
New Token entry, which bob, who may not read it, does not see; granted
`read` and `write` on it, and `write` on the tokens he owns, in the
game's data through the server's console, bob enters the game again,
sees it and drags it together with Bilbo in one drag, which adam's
client and the save show; adam deletes it from the token panel and bob loses it,
the grants naming it gone from the save; bob's New Token entry is
read-only, and piotr's creation and deletion sent past his gate are
refused with their reasons) and `game-panels` (the side panels over
the wire: adam creates the page `Cellar` from the Pages panel, its
image picked in the workspace, shows it from the Game panel and bob's
client switches to it, sets piotr's grants to `write:tokens` from the
Permissions panel, which bob's session holds within the wait and his
New Token entry becomes writable, creates the token property `hp` and
retitles the group `player`, the save holding each, and shows Meadow
again on both clients; a page creation bob sends past his gate is
refused with its reason and nothing saved) and `delete-game` (bob, as
piotr, finds no game to delete under Delete and a deletion sent past
his gate refused with the reason, then enters Meadow; adam picks Meadow
under Delete, answers No to the question and nothing changes, then
deletes it with Yes and lands on the Games menu with the notification,
bob's client is back on the menu with it, without the game's data and
store, and the server lists no game and has no session in one). The shared steps `steps.select_token` and
`steps.drag_token` select a token with a rectangle and drag it with the
token-drag button, as a player does, `steps.select_tokens` several with
one rectangle; `steps.open_games_menu` opens the Games menu from the
menu, `steps.enter_game` enters a game from the menu through it,
`steps.open_delete_game` opens the games to delete, `steps.delete_game`
picks a game among them by its name and answers Yes, `steps.create_token` creates one through the New Token
screen and `steps.delete_token` deletes one, selected alone, from the
panel. For the side panels: `steps.open_panel` shows one by its quick
access entry (an entry already active is not clicked again, which would
hide its panel) and returns it, `steps.select_entry` selects an entry
in an entries panel's list, `steps.set_text` replaces a field's text as
a player types it (the field clicked, Ctrl+A, the text typed over the
selection) and `steps.pick_image` picks an image in the workspace a
Browse... button opened, with Use. `edit-text` edits the Login field
with the caret and the selection: a move, a delete, a selection by
Shift, Ctrl+A, a copy and a paste, each checked on the field's text,
caret and selection, then `steps.set_text` and the login.

### The fixture

`--fixture <path>` names a directory of the source tree mirroring the
server root: `accounts.lua` and `games/<id>/` with its `save.lua` and
`assets/`. At load the server empties its root in the save directory and
copies the fixture in (`data/fixture.lua`), so every run starts from the
same state; the option needs `--identity`, so a fixture never lands on
the default save directory, the user's. Two fixtures live under
`scenarios/fixtures/`. `basic`, the default: the accounts `adam`
(password `krause`) and `piotr` (password `secret`), one game, `Meadow`,
with adam in the master group, piotr in a player group that reads the
tokens he owns only, one page with a small image, two tokens with small
avatars, Bilbo owned by piotr. `old-town`: the same `adam`, `piotr` with
the password `stępczyński`, and the game `Old Town`, a page of 175 meters
over a real map, the tokens `Bilbosz`, `Gaben`, `Bilbosza` and `Anonim`
with real avatars, piotr a player who writes the tokens he owns and views
`Bilbosz`. A scenario names the fixture it needs in its table form,
`fixture = "old-town"` beside `run`; `scenario.sh` reads it
(`tools/scenario-info.lua`) and seeds the server from it, `basic` without
one, and `--fixture <dir>` on its command line overrides.

### Running one

```bash
./scenario.sh join-game              # headless: exit code 0 or 1, logs under /tmp/treflove-scenario/<name>/
./scenario.sh join-game --windowed   # the same in a window, the app stays open
./scenario.sh old-town --windowed    # the Old Town world, the app left in the game
```

The script starts a server on its own port and identity
(`treflove-scenario`) with the fixture and a console, then the client with
the scenario, its console and the server's, stops the server at the end
and exits with the client's code. It refuses to start when one of its
console ports is in use, since `run.sh`'s client and server listen on the
same defaults and the scenario's server calls would reach them: pass
`--console` and `--server-console` of your own then, and `--identity`
for a run beside another (its save directories and its logs, under
`/tmp/treflove-scenario/<identity>/<name>/`, are then its own). `run.sh`
and the `Client` launch configuration pass no scenario; the
`Scenario (headless)` launch configuration runs one by name under the
debugger, with breakpoints in the scenario file (its tasks start and stop
the scenario server, seeded from the scenario's fixture).

## The console

`--console <port>` opens a TCP port on 127.0.0.1 (`Console`,
`app/console.lua`), serviced on `app.service_event` once per loop
iteration, so every chunk sees a consistent world between two frames,
never a half-updated one. It is arbitrary code execution by design:
localhost only, never on by default. A port that cannot be bound is
logged and the program runs without.

A frame is a header line `<kind> <length>` and `<length>` bytes of body.
The client sends `eval` with a Lua chunk; the console answers `ok` (the
return values, tables serialized, joined by tabs) or `error` (the message
with a traceback), and sends `watch` and `log` frames on its own. The
chunk runs under an environment over `_G` that carries:

| Function | Effect |
| --- | --- |
| `watch(name, fn)` | `fn()` is evaluated every iteration; its first value and every change go to every console client as `name`, the frame, the app time and the value |
| `unwatch(name)`, `watches()` | |
| `pause()`, `resume()`, `frames(n)` | the main loop's pause, resume and step |
| `screenshot(name)` | the absolute path; the file exists once the frame is drawn |
| `log(enabled)` | the app's log lines streamed as `log` frames |
| `scenario(name)` | client only: runs a scenario on the live program, which stays afterwards |
| `run(chunk)` | client only: runs the chunk as a scenario with `driver` and `steps` in scope; the reply comes when it has finished, `ok` with its return values or `error` with the traceback; no other frame of that connection is read meanwhile |
| `quit(exit_code)` | |

The command line client:

```bash
luajit tools/console.lua 9090 'return get_class_name_of(app.screen_manager:get_screen())'
luajit tools/console.lua 9090 --watch 'get_class_name_of(app.screen_manager:get_screen())'   # stays, one line per change
luajit tools/console.lua 9090 --follow 'log(true)'                                            # the log, live
luajit tools/console.lua 9090 < probe.lua                                                      # a file as the chunk
```

The options go before or after the port. Exit codes: 0 for a result, 1
for an error reply, 2 for a usage or connection failure.

The same command runs under LÖVE, so a user needs no LuaJIT on the path:
`love . console 127.0.0.1 9090 'return 1 + 1'`, with the chunk from the
argument or stdin, `--follow` and `--watch` as above and the same exit
codes; it pumps LÖVE's events between short polls, so Ctrl-C ends a
following session as it does under LuaJIT, which simply dies. Both entry
points share `ConsoleSession` (`utils/console-session.lua`); the LÖVE one
is `ConsoleApp` (`app/console-app.lua`), a `love.run` of its own without
a window. LÖVE starts in a fifth of a second, LuaJIT at once, so scripts
that fire many calls keep the LuaJIT entry.

`ConsoleClient` (`utils/console-client.lua`) is the client end the CLI,
the monitor and the scenario driver use.

The watch overlay (`ui/watch-overlay.lua`, on `app.overlay`, drawn after
the root and never hit) shows the watches' current values in the window;
`TOGGLE_WATCH_OVERLAY_KEY` (F3) shows and hides it.

### The monitor

`love . monitor <address> client:9090,server:9091` opens a window of its
own (`Monitor`, `app/monitor.lua`, built with the project's controls on
`UiApp`, the part of the client every windowed app shares) connected to
every target named: a button per target across the top with its name and
state, the selected target's watches on the left (`name: value`, live),
its log on the right (the console streams it with `log(true)` at every
connect), and a line along the bottom: Enter evaluates the text on the
selected target and logs the reply with a `>`; a leading `=` adds the
rest as a watch. A target that is not up yet, or that quit, is retried
every `MONITOR_RECONNECT_SECONDS`, and the console tells a newly
connected client the watches it holds with their current values, so the
monitor shows them at once after a restart. This is the window for
watching values through a transition: set the watches here or from the
CLI, keep the window beside the game, and play; the server, which has no
window, shows here too. `MonitorTarget` (`app/monitor-target.lua`) is one
connection with its state, watches and log; `MonitorScreen`
(`screens/monitor-screen.lua`) the screen. With `--console` the monitor
has a console of its own, which is how it is driven headless.

### The console and the debugger

They are complementary. The debugger (development.md, "Debugging")
steps into a function and reads a frame's locals; the console runs
anything between frames, watches a value over minutes, pauses the loop
for real, and is driven from a shell. Both can be attached at once; while
the debugger holds the program paused the console simply waits.

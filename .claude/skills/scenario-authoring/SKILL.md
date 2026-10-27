---
name: scenario-authoring
description: Write, run and debug Treflove scenarios - the Lua files under scenarios/ that drive the client through its real UI (log in, join the game, open the workspace, rename a token) headless or in a window, single client or several clients at once, against a server seeded from a fixture. Use it whenever a flow should be covered end to end, a reported bug should be reproduced by a scenario name, the user wants the app started at a given state, a fixture needs a player or a token, or a scenario fails and has to be read and fixed; even when the user says "test it in the real app" without the word scenario. For inspecting a running program without a scenario use live-console; for breakpoints use debug-live.
---

# Writing and running scenarios

A scenario is the project's end-to-end test and its dev bookmark in one
file: the client is driven through its real UI by the same LÖVE events a
hand would cause, headless in under a second or in a window the user
watches. The design is `docs/scenarios-and-console.md`; this skill is the
practice. The full driver API is `references/driver-api.md`; read it
before writing a scenario that does more than the examples here. The
sibling skills: `headless-smoke` for a check of the real program without
writing a scenario, `live-console` for a program already running,
`debug-live` for breakpoints.

## The shape

```lua
local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    local game = steps.join_game(driver)                 -- the login, "Games" and the game "Meadow", as adam
    driver:click("TextButton", "Assets")                 -- a control by class and caption
    driver:wait_screen("AssetsWorkspaceScreen")
    driver:expect(driver:try_find("AssetListRow", "token/"), "the store's token folder is listed")
    driver:key(Consts.BACKSTACK_KEY)                     -- Escape: the back key, as the steps write it
    driver:wait_screen("GameScreen")
end
```

The file is `scenarios/<name>.lua`, the name in `kebab-case`, run with
`./scenario.sh <name>`. A scenario that drives other clients returns a
table instead: `{peers = {"bob"}, run = function(driver) ... end}`; the
script starts one extra client per peer (see "Several clients").

## Rules that make a scenario hold

- **Find, never aim.** `find(class_name, caption, index)` walks the
  shown controls in draw order and matches the class name exactly and
  the caption against the control's own text (a `Text` or a `TextInput`)
  or a descendant `Text`. A button is `("TextButton", "Sign In")`, on
  the menus too (their entries, `MenuTextButton` and `MenuTextInput`, are
  not controls: they build a `TextButton` or a `TextInput`); a text field
  has no caption of its own, so the login fields are `("TextInput", nil,
  1)` and `("TextInput", nil, 2)`; a token is `("Token", "Bilbo
  Baggins")`, a workspace row `("AssetListRow", "token/")`. Coordinates
  break with the layout; names do not. When unsure what a screen holds,
  the control dump names every control with its caption.
- **Wait on state, never on time.** `wait_screen("GameScreen")` and
  `wait_for(function() return ... end, timeout, "what")` yield frames
  until the condition holds and time out on the wall clock (10 s by
  default), so a run that is fast or slow passes alike. After a click
  that changes the screen, wait for the screen; after one that asks the
  server, wait for what the reply changes.
- **Jump the app's clock for app timers.** `advance(seconds)` adds
  seconds to the next frame's delta: a notification's duration, a
  deferred call, an autosave cadence pass in one frame. It does nothing
  for the network, which lives in real time, so never use it to "wait
  for the server".
- **One yield per action.** `click`, `key` and `type` queue their events
  and yield one frame so they are dispatched; `move`, `press` and
  `release_button` only queue, for a drag, which then needs `frames(1)`
  to be delivered.
- **Expect with the value in the message**: `driver:expect(n == 2, "two
  tokens on the page: " .. n)`, so the failure log says what was found.
- **Share the steps.** `scenarios/lib/steps.lua` holds `log_in` (returns
  the menu screen), `join_game` (returns the game screen), `log_out`,
  `open_assets_workspace`, `server_sessions`; a step used by two
  scenarios goes there, named for what it reaches. The folder is skipped
  by `./format-code.sh`, which skips every path containing `lib/` and
  rewrites the whole project, so one file is formatted with `lua-format
  -i <file>` and checked with `lua-format --check <file>`,
  `./lint-code.sh <file>` and `./diagnose-code.sh <file>` (`{}` when
  clean).
- **List it.** A new scenario is named in `docs/scenarios-and-console.md`
  next to the others, with what it covers in a few words.
- **Ask the server with `driver:server(chunk)`**: the chunk runs on the
  server's console; several return values come back tab-joined as one
  string, a table serialized. Compare strings, or `string.match` the
  tab-separated fields. A scenario that proves a login or a change also
  asks the server (`steps.server_sessions`, the data), since the client's
  screen alone does not show what the server holds.
- The pointer release is `release_button`, since `release` is every
  object's destructor on this branch.

## Several clients

```lua
return {
    peers = {"bob"},
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", [[ steps.join_game(driver, "piotr", "secret") ]])
        steps.join_game(driver)          -- the lead goes on while bob logs in
        bob:wait()                       -- yields frames until bob's chunk is done
        local n = driver:client("bob", [[ return #app.session:get_game_screen():get_page():get_tokens() ]]):wait()
        driver:expect(n == "1", "piotr reads only the token he owns: " .. n)
    end
}
```

A chunk runs on the peer as a scenario of its own, with `driver` and
`steps` in scope, through the console's `run` verb; `wait` raises with
the peer's name when the peer's run failed, and a chunk that only
returns a value is a run that ends at once, so one primitive serves
steps and questions. Each peer has its own identity and log
(`/tmp/treflove-scenario/<name>/<peer>.log`). What two clients can show
today: each player's game filtered by their grants, the shared asset
store, one logging out while the other stays. Seeing each other's moves
waits for game state synchronization.

## The fixture

A fixture under `scenarios/fixtures/` mirrors the server root:
`accounts.lua` (the accounts by login: `name` and `auth`) and
`games/<id>/` with its `save.lua` (the `GameData` shape, see
`game/game-data-rp.lua`) and `assets/`. `basic`, the default, has tiny
real images (LÖVE decodes them): `adam`/`krause` is the master of
`Meadow`, `piotr`/`secret` a player who reads the tokens he owns only.
`old-town` is the world the server used to seed itself from: a real map,
four tokens with real avatars, `adam`/`krause` its master. A scenario
that needs a fixture other than `basic` says so in its table form,
`fixture = "old-town"` beside `run` (and `peers`); `scenario.sh` reads
the name with `tools/scenario-info.lua`. The server itself never seeds:
`--fixture` is the scenario tooling and needs `--identity`, so a run on
the user's default save directory is refused. To add an account, compute
the `auth` with the script, which runs the project's own hashing under
LÖVE:

```bash
.claude/skills/scenario-authoring/scripts/player-auth.sh gandalf mellon
```

and add it to `accounts.lua` as `{name = ..., auth = ...}`; to put it in
the game, add it to the game's `players` as `{group = ...}`, with
`permissions = {...}` for grants of its own (`PlayerData` in
`game/game-data-rp.lua`, the grants in `docs/permissions.md`); an
account that is not in `players` joins the game as a `player` at its
first click on it. A new token goes into `tokens` and into its page's
`tokens` list; a new image into the game's `assets/`; a second game is
another directory under `games/`. An account made by a scenario
(`steps.sign_up`) is in the server's root for that run only. A fixture change is written into the fixture paragraphs
of `docs/scenarios-and-console.md` and of `references/driver-api.md`. Every run reseeds the server root from the fixture, so a
scenario never depends on a previous run; the client's cache (`c/` under
the run's identity) stays, which is harmless.

## Running and reading a failure

```bash
./scenario.sh <name>                                   # headless, nothing on screen, the server included; the client log printed
./scenario.sh <name> --port 8282 --console 9270 --server-console 9271 --identity mine   # beside other runs; peers on 9280, 9281, ...
./scenario.sh <name> --windowed                        # only when the user asked to watch
```

Exit codes: 0 passed, 1 failed, 2 a usage error or a console port in
use, 124 the client killed by the timeout. The log's time column is the
wall clock, so headless steps lie milliseconds apart, not frames.

The script starts the server, the peers and the client, and stops the
server and the peers by PID when it exits, so a run leaves nothing to
kill. The logs are `/tmp/treflove-scenario/<name>/client.log`,
`server.log` and `<peer>.log` (under `/tmp/treflove-scenario/<identity>/`
with `--identity`); only the client's is printed. The script refuses to
start when one of its console ports is in use, because `run.sh`'s client
and server listen on the same defaults and the scenario's server calls
would reach the user's server: pass ports of your own then (the peers
take `console + 10 + i`, so leave room; the UDP game port is not checked,
`ss -ulnp` shows it), and never kill the user's processes. Two runs at
once need identities of their own (`--identity`), since a run reseeds its
server's save directory at startup. A failure logs
`scenario <name>: failed: scenarios/<name>.lua:<line>: <message>`, the
traceback and the control dump (`Utils.dump_controls`): the screen as a
tree of class names with `e` enabled, `v` visible, `a` all predecessors
enabled, and the caption of every text, field and button. Read the dump
before a screenshot: a `find` that failed names what it looked for, and
the dump shows what was there instead (the screen still loading, a
button disabled, a caption that differs).

To stop at the failure state: run the scenario on a live client through
its console, `luajit tools/console.lua 9090 'scenario("<name>")'`, which
leaves the program where it failed for inspection (live-console); or the
`Scenario (headless)` launch configuration, which asks for the name and
runs it under the debugger with breakpoints in the scenario file
(debug-live).

## Pitfalls

- A windowed client started from a shell on this machine presents at one
  frame per second (adaptive vsync under XWayland), so a windowed
  scenario takes a second per step; headless is unaffected.
- `wait_screen` is on the class name of the screen manager's current
  screen: the waiting screen shows between the click on a game in the
  games list and the game, so wait for `GameScreen`, not for the waiting
  screen to go.
- A peer's chunk is a string: quote it with `[[ ]]`, and build it with
  `string.format("%q")` when it carries a value.
- The scenario given on the command line quits a headless client at its
  end; one started through the console leaves it running.
- Escape on the user menu logs out (it is the logged-in period's back
  entry): one Escape too many in a menu scenario lands on the login
  screen.

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
before writing a scenario that does more than the examples here.

## The shape

```lua
local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    local game = steps.join_game(driver)                 -- the login and "Join Game", as adam
    driver:click("TextButton", "Assets")                 -- a control by class and caption
    driver:wait_screen("AssetsWorkspaceScreen")
    driver:expect(driver:try_find("AssetListRow", "token/"), "the store's token folder is listed")
    driver:key("escape")
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
  or a descendant `Text`. A button is `("TextButton", "Sign In")`; a
  text field has no caption of its own, so the login fields are
  `("TextInput", nil, 1)` and `("TextInput", nil, 2)`; a token is
  `("Token", "Bilbo Baggins")`, a workspace row `("AssetListRow",
  "token/")`. Coordinates break with the layout; names do not.
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
- **Share the steps.** `scenarios/lib/steps.lua` holds `log_in`,
  `join_game`, `log_out`, `open_assets_workspace`, `server_sessions`; a
  step used by two scenarios goes there, named for what it reaches. The
  folder is skipped by `./format-code.sh` like `tests/lib/`, so run
  `lua-format -i` on it by hand.
- **Ask the server with `driver:server(chunk)`**: the chunk runs on the
  server's console; several return values come back tab-joined as one
  string, a table serialized. Compare strings, or `string.match` the
  tab-separated fields.
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

`scenarios/fixtures/basic/` mirrors the server root: `save.lua` (the
`GameData` shape, see `game/game-data-rp.lua`) and `assets/` with tiny
real images (LÖVE decodes them). `adam`/`krause` is the master, `piotr`/
`secret` a player who reads the tokens he owns only. To add a player,
compute the `auth` with the script, which runs the project's own hashing
under LÖVE:

```bash
.claude/skills/scenario-authoring/scripts/player-auth.sh gandalf mellon
```

and add the player to `players` with its `group`; a new token goes into
`tokens` and into its page's `tokens` list; a new image into `assets/`.
Every run reseeds the server root from the fixture, so a scenario never
depends on a previous run; the client's cache (`c/` under
`treflove-scenario`) stays, which is harmless.

## Running and reading a failure

```bash
./scenario.sh <name>                                   # headless; exit 0 or 1; both logs printed
./scenario.sh <name> --port 8282 --console 9290 --server-console 9291   # when the defaults are in use
./scenario.sh <name> --windowed                        # only when the user asked to watch
```

The script refuses to start when one of its console ports is in use,
because `run.sh`'s client and server listen on the same defaults and the
scenario's server calls would reach the user's server: pass ports of your
own then, and never kill the user's processes. A failure logs
`scenario <name>: failed: scenarios/<name>.lua:<line>: <message>`, the
traceback and the control dump (`Utils.dump_controls`): the screen as a
tree of class names with `e` enabled, `v` visible, `a` all predecessors
enabled. Read the dump before a screenshot: a `find` that failed names
what it looked for, and the dump shows what was there instead (the
screen still loading, a button disabled, a caption that differs).

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
  screen: the waiting screen shows between "Join Game" and the game, so
  wait for `GameScreen`, not for the waiting screen to go.
- A peer's chunk is a string: quote it with `[[ ]]`, and build it with
  `string.format("%q")` when it carries a value.
- The scenario given on the command line quits a headless client at its
  end; one started through the console leaves it running.

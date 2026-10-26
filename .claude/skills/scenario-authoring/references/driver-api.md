# The scenario driver, method by method

`ScenarioDriver` (`app/scenario-driver.lua`) is what a scenario receives.
Every "yields" below means the method gives the frame back to the main
loop and resumes at the next update; the events it queued are dispatched
by the loop's poll in between, through the same callbacks as real input.

| Method | Does | Notes |
| --- | --- | --- |
| `wait_for(predicate, timeout?, what?)` | yields until `predicate()` is truthy; returns that value | wall-clock timeout, default `SCENARIO_WAIT_TIMEOUT` (10 s); raises `timed out waiting for <what>` |
| `wait_screen(class_name, timeout?)` | `wait_for` on the shown screen's class name; returns the screen | the screen manager's current screen |
| `frames(n)` | yields n frames | |
| `advance(seconds)` | adds seconds to the next update's delta, yields one frame | app timers only; the network keeps real time |
| `screen()` | the shown screen or nil | |
| `find(class_name, text?, index?)` | the index-th (default 1) visible control of that class, with that text when given; raises with the control dump when none | draw order; class name exact; text is the control's own (`Text`, `TextInput`) or a descendant `Text`'s |
| `try_find(...)` | as `find`, nil when none | |
| `click(target, text?, index?)` | a control or `find(...)`; queues move, press, release of button 1 at the center of its bounding box; yields one frame | |
| `move(x, y)`, `press(x, y, button?)`, `release_button(x, y, button?)` | queue the pointer events; no yield | a drag: press, moves, release, then `frames(1)` |
| `key(key)` | queues keypressed and keyreleased; yields one frame | `"escape"` is the back key, `"return"` submits a field |
| `type(text)` | queues one textinput per UTF-8 character; yields one frame | the focused field receives it; click the field first |
| `expect(condition, message)` | raises `message` when falsy, at the scenario's line | put the found value in the message |
| `log(message)` | `app:log("scenario: " .. message)`, flushed | shows in the client log with a timestamp |
| `server(chunk)` | runs the chunk on the server's console, returns the `ok` body | needs `--server-console` (the script passes it); raises with the error body |
| `peers()` | the peer names of the command line, sorted | empty without `--peers` |
| `client(name, chunk)` | sends the chunk to the peer's console as a `run`; returns a `ScenarioPeerRun` | the chunk sees `driver` and `steps`; connects on the first call |
| `ScenarioPeerRun:is_done()` | polls the peer's connection, answers | |
| `ScenarioPeerRun:wait(timeout?)` | yields until done; returns the `ok` body; raises `peer <name>: <error>` | |
| `screenshot(name)` | `love.graphics.captureScreenshot`, yields one frame, returns the absolute path | under the client's save directory |
| `quit(exit_code?)` | the app quits at the next update | the command line scenario quits by itself at its end, headless |
| `headless` | true under `--headless` | |

The reply of `server` and of a peer's chunk is the console's `ok` body:
the return values, a table through `table.to_string`, anything else
through `tostring`, joined by tabs; no value gives an empty string. A
number comes back as its string.

The shared steps (`scenarios/lib/steps.lua`): `log_in(driver, login?,
password?)` (waits for the login screen, fills both fields, "Sign In",
waits for the menu, returns it), `join_game(driver, login?, password?)`
(then "Join Game", waits for the game screen, returns it), `log_out(driver)` (Escape
to the menu, "Log Out", waits for the login screen),
`open_assets_workspace(driver)` ("Assets", waits for the listing),
`server_sessions(driver)` (the server's connection count and its
logged-in users).

What the fixture's basic world holds: the page `Meadow` with the tokens
`Bilbo` ("Bilbo Baggins", owned by adam and piotr) and `Smaug`; adam in
`master` (`read`, `write`); piotr in `player` (reads the game, pages,
token properties, players, groups, assets, and `tokens/@owned`); the
store `assets/world/world.png`, `assets/token/bilbo.png`,
`assets/token/smaug.png`.

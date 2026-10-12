# Lifetimes

Converted modules use the lua-lifetime extension: owned and scoped objects
with destructors ([lib/lua-lifetime](../lib/lua-lifetime), the semantics in
`lib/lua-lifetime/docs/02-semantics.md`). The earlier trial
`lib/lua-lifetime/trial/treflove/README.md` ported a slice of Treflove to it
and shows the teardown order the ported code must have.

## The Extension in One Screen

- `x @ owner` - `x` lives while `owner` does and while it is referenced
  (the implicit `reachable` term); `@ (a, b)` - while both live.
- `lifetime.destroy(x)` - `x` dies now: its own destructor first, with
  every dependent alive, then its dependents, most recently attached
  first, each by the same rule ("Cascading death").
- `f !@ x` - a hook: `f(reason)` runs when `x` dies, in its place among
  `x`'s dependents.
- `local t = make() @ lifetime.scope` - `t` dies at the block exit.
- `lifetime.token("name")` - a value with no data, a period to anchor to.
- A dead object is a **tombstone**: the reference stays, indexing it
  raises, `lifetime.alive(x)` is the check. Do not `nil` a field to
  "release" an object.

## Classes

[utils/class.tlt](../utils/class.tlt) ties the class system to the runtime:

- The instance metatable's `__destroy` calls the object's `release(reason)`
  if it has one, so `release` bodies are the destructors.
- Every instance of a class that has a `release` is registered
  (`obj @ lifetime.reachable`) right after `init`, so a collected instance
  still runs its `release` (reason `"unreachable"`); a constructor that
  raises leaves nothing registered. An instance of a class with no
  `release` has nothing to run and is not registered.
- `App` defines `love.quit` to call `lifetime.set_exiting(true)`, so what
  the closing state finalizes dies with the reason `"exit"`.

## Ownership

- **No call site calls `x:release()` on an object someone else owns.**
  Ownership is written where the object is made (`Login(...) @ self`), and
  a root dies by `lifetime.destroy(x)`; the cascade releases its dependents.
  A destructor does not release its dependents by hand (that would be a
  second release).
- A registered object released by hand would run its `release` again when
  collected; Lua code not converted yet therefore ends the lifetime of what
  it owns with `lifetime.destroy(x)` (`local lifetime = require("lifetime")`)
  and anchors with `lifetime.attach(x, false, owner)`, which is what
  `x @ owner` compiles to. Until they are converted, `Session:release` and
  `Login:release` still end some of their dependents' lifetimes by hand (through
  `lifetime.destroy`, which is a no-op on a dying object, so the cascade
  does not release them twice).
- Objects in one ownership tree are anchored to their owner, so that the
  collector (and program end) finalizes the owner before them: within one
  collection anchors are finalized first, otherwise newest first.
- The control tree is **not** an ownership tree (children are added,
  removed and reparented): never anchor a control to its parent for that
  reason. What a screen or panel creates for itself and undoes in its
  `release` (images, event registrations) stays in that `release`.
- Lists unlink their elements in hooks: a dead element stays in an array
  as a tombstone until something removes it by identity, and the hook runs
  while the element is dying and still findable.

### Networking

A connection is a root. `ConnectionManager:remove` takes it out of its
three tables (a tombstone is not `nil`, so it would not leave them by
itself), runs the disconnect callback and ends with
`lifetime.destroy(connection)`: `Connection:release` runs first, then
whatever is anchored to the connection, most recently attached first
(lua-lifetime `docs/02-semantics.md`, "Cascading death";
[tests/test-connection.lua](../tests/test-connection.lua) asserts the
sequence). `Connection:release` keeps releasing what the connection holds
- the two threads, the two channels and its `app.update_event`
registration - instead of anchoring them `@ self`: the threads and
channels are LÖVE userdata, whose `__destroy` the runtime looks up on the
shared per-type metatable, which LÖVE's objects do not have ("`__destroy`
and reasons", rule 1), so an anchor would release nothing, and a hook per
object would restate the body in four closures; the update registration
must end in the body, because a destroyed connection stays a key of the
event's weak table until it is collected, and the next frame would call
`on_update` on its tombstone (lua-lifetime `trial/treflove/README.md`,
finding 7). The body runs before the dependents, which still reach the
connection: a dying object is not dead ("Tombstones").

Remote procedures are anchored to their owner (`LoginRp(...) @ self`) and
`RemoteProcedure:release` is `self:stop()` only, so a second release is
harmless. `AssetManager:register_session` anchors the session's three
procedures `@ session`, and there is no `unregister_session`: the
per-session tables are weak in keys and values (5.1 has no ephemerons,
and a procedure refers back to its session's connection through its
request handler), and a hook on the session removes its three entries as
it dies, so a reconnected client never picks a dead procedure from them
([tests/test-asset-manager.lua](../tests/test-asset-manager.lua)).

### Screens

The [ScreenManager](../screens/screen-manager.tlt) holds the current
screen but owns no screen: `show(next)` calls the current screen's
`hide`, which undoes what its `show` registered (a FormScreen's key
handler and its inputs' button, update, text and key registrations), and
then drops the reference. Who makes a screen decides how it ends:

- **Dropped and collected**: a WaitingScreen (`Session:join_game`,
  `GameDataRp`) and an OptionsMenuScreen (`UserMenuScreen:options`) are
  held by the manager alone and are collected once replaced. A
  WaitingScreen has no `release`, so nothing runs; an OptionsMenuScreen
  runs FormScreen's `release` with the reason `"unreachable"`, and the
  hooks of its inputs, which die with it, find the flag and do nothing.
- **Kept**: the client's ConnectingScreen is held by its disconnect
  callback and shown again on every disconnect; the server's ScreenSaver
  is shown once. Neither is ever destroyed.
- **Owned**: a GameScreen (made by `GameDataRp`) is destroyed by its own
  back entry, after that entry has shown the user menu; it owns its panels
  (`@ self`). On the client the user menu screen belongs to the logged-in
  period and the login screen to the session (anchored there once
  `game/session` is converted).
  UserMenuScreen anchors the back entry it pushes for the options menu to
  itself (`push(...) @ self`), since the entry's callback shows it: when
  the screen dies, the entry dies too and leaves the stack.

A screen dies only **after it has been replaced**: `show` the next screen
first, then `lifetime.destroy` the old one or what owns it. A screen
destroyed while shown would leave its root control under `app.root` and
its registrations live (the control tree is not an ownership tree, and
`release` does not hide), and the manager would call `hide` on its
tombstone at the next `show`.

A [FormScreen](../ui/form-screen.tlt) keeps its inputs in a list, and each
[Input](../ui/input.tlt) unlinks itself (idiom B of the trial):
`Input:init` attaches `function() if not form_screen:is_released() then
form_screen:remove_input(self) end end !@ (form_screen, self)`, and
`FormScreen:release`, the form's destructor, sets the flag `is_released`
reads. A hook runs after its anchor's destructor, among its dependents
("Hooks: the `!@` operator"), and learns only the reason, not which anchor
died, so the flag tells the two orders apart: an input that dies first is
removed from the list while it is dying and still findable; a form that
dies first has said so, and the hooks do nothing (the inputs live on);
when the inputs are the form's dependents, one cascade runs the form's
`release` first and nothing is unlinked
([tests/test-form-screen.lua](../tests/test-form-screen.lua) asserts the
three logs, and the removal by hand below). The input keeps the hook in `_unlink_hook`, and
`remove_input` discards it, so an input removed by hand (TokenPanel drops
and replaces its inputs) is not pinned to the form by its hook; from the
hook itself the discard is a no-op. Inputs have no destructor: an input
is not destroyed while its form is shown, since its `on_screen_hide`
registrations would outlive it.

## Back Navigation

`BackstackManager:push(cb)` returns an entry `{cb = cb}` with a hook that
removes it from the stack as it dies. The caller anchors the entry to what
it belongs to (`app.backstack_manager:push(cb) @ period`) or destroys it
(`lifetime.destroy(entry)`); `back()` destroys the top entry, then runs its
callback; `get_top()` returns the entry. There is no `pop`.

## Tables

A table the runtime has seen carries its state record in one extra field
under a private table key, which `pairs` and `next` show. `table_utils`
skips it (`lifetime.is_state(k)`) in `merge`, `copy`, `deep_copy`,
`is_empty` and the copying iterators; `to_string` writes no table keys.
Any other walk over a seen table skips it the same way.

## Tests

A test asserts the **order** of deaths and the statement that caused them,
not only that something died. A death by the collector is pinned with
`collectgarbage("collect")`, twice when a weak table must have cleared,
never with timing. See [tests/test-lifetime-class.lua](../tests/test-lifetime-class.lua).

# Lifetimes

Every module uses the lua-lifetime extension: owned and scoped objects
with destructors ([lib/lua-lifetime](../lib/lua-lifetime), the semantics in
`lib/lua-lifetime/docs/02-semantics.md`). The trial
`lib/lua-lifetime/trial/treflove/README.md` ported a slice of Treflove to it
first; its idioms (A: owners written where objects are made, B: hooks that
unlink, C: periods as tokens) are the ones used here, and the comments cite
them by letter.

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
- `App` defines `love.quit` to call `lifetime.set_exiting(true)`, so an
  object the closing state finalizes dies with the reason `"exit"`, and
  its dependents in that cascade with `"anchor"` (the quit entry, in the
  app's).

## Ownership

- **No call site calls `x:release()` on an object someone else owns.**
  Ownership is written where the object is made (`Login(...) @ self`), and
  a root dies by `lifetime.destroy(x)`; the cascade releases its dependents.
  A destructor does not release its dependents by hand (that would be a
  second release).
- A registered object released by hand would run its `release` again when
  it dies, so nothing calls `release` by hand: an object that must end now
  is destroyed (`lifetime.destroy(x)`), which runs its `release` once. (Two
  tests call a `release` body on purpose, to check that it is harmless to
  repeat or what it undoes: `Event:release` in
  [tests/test-event.tlt](../tests/test-event.tlt), `RemoteProcedure:release`
  in [tests/test-connection.tlt](../tests/test-connection.tlt).)
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

### The Tree

What anchors what, in the order each owner attaches its dependents (a
cascade runs the owner's `release` first, then the dependents from the
bottom of its list up: most recently attached first, "Cascading death").
`@` is an anchor, `!@` a hook; a name in brackets has no `release`, so
dying runs nothing of its own.

```
connection                          root: ConnectionManager:remove destroys it
└─ [Session] @ connection           Client:load / Server:load connection callback
   ├─ [Login] @ session             Session.init
   │  ├─ LoginRp @ login
   │  └─ LogoutRp @ login
   ├─ GameDataRp @ session          Session.init
   │  └─ GameScreen @ game_data_rp  client: GameDataRp:receive_response
   │     ├─ hook !@ (screen, input) one per input, as it is made (ui/input.tlt)
   │     ├─ [AssetsPanel] @ screen
   │     │  └─ PreviewArea @ panel  its release ends its drop registration
   │     └─ [back entry] @ screen   GameScreen:show; hook !@ entry leaves the stack
   ├─ UploadAssetRp @ session       AssetManager:register_session
   ├─ DownloadAssetRp @ session
   ├─ DownloadMissingAssetsRp @ session
   ├─ hook !@ session               clears the session's AssetManager entries
   ├─ [period] @ session            client, Session _on_login: lifetime.token("period")
   │  ├─ UserMenuScreen @ period    Session:show_user_menu (at login)
   │  │  └─ [options entry] @ menu  UserMenuScreen:options
   │  ├─ [logout entry] @ period
   │  └─ UserMenuScreen @ period    Session:show_user_menu (each game screen's back entry)
   │     └─ [options entry] @ menu
   └─ LoginScreen @ session         client, Session _on_logout (one per logout)

app (Client)                        lives as long as the program
└─ [quit entry] @ app               Client:load: the bottom of the back stack
```

Where roots die:

- **A connection** dies in `ConnectionManager:remove` (both sides), after
  the disconnect callback: the client's shows the connecting screen first
  (the game, menu or login screen it replaces dies in the cascade) and
  clears `app.session` and `app.data`; the server's clears
  `_sessions[connection]` (a tombstone would stay a key). A connection
  nobody refers to any more is collected with its whole tree in the same
  order (the connection with the reason `"unreachable"`, the tree below it
  with `"anchor"`), and at program end what is left dies the same way, the
  root with `"exit"`.
- **The period** dies in `Session` `_on_logout`, after the login screen
  has replaced the menu (see "Screens"); the back key may have destroyed
  the logout entry already (`back()` destroys the top entry before running
  it), and destroying a dead object is a no-op.
- **A game screen** is destroyed by its own back entry, after the entry
  has shown a user menu (`Session:show_user_menu`, so the menu belongs to
  the period).
- **A back entry** dies when `back()` destroys it, or with its owner.

The asset procedures sit under the session, not under Login or a screen,
because both sides use them for the whole connection. Nothing in the tree
is a control's parent: the controls of a screen are reachable from it and
go with it, and only what holds a resource of its own (`PreviewArea`'s
drop registration) or is listed somewhere (inputs, back entries, asset
entries) needs a `release` or a hook. The whole tree is asserted, order and
statement of each death, in [tests/test-session.tlt](../tests/test-session.tlt).

The `release` bodies that remain, and what ends them:

| `release` | What it undoes | Ended by |
| --- | --- | --- |
| `Connection` | its threads, channels, update registration | `ConnectionManager:remove`; the collector; program end |
| `RemoteProcedure` | `self:stop()`: its request handler | its owner's cascade (Login, Session) |
| `FormScreen` | sets `_is_released` for its inputs' hooks | the period (every UserMenuScreen), the session (LoginScreen), GameDataRp or the game screen's own back entry (GameScreen); the collector for screens nobody owns or that were replaced (OptionsMenuScreen, a replaced UserMenuScreen or LoginScreen) |
| `PreviewArea` | its drop registration | its AssetsPanel's cascade, from the GameScreen |
| `Event` | its handlers | the collector or program end, with its manager |

### Networking

A connection is a root. `ConnectionManager:remove` takes it out of its
three tables (a tombstone is not `nil`, so it would not leave them by
itself), runs the disconnect callback and ends with
`lifetime.destroy(connection)`: `Connection:release` runs first, then
whatever is anchored to the connection, most recently attached first
(lua-lifetime `docs/02-semantics.md`, "Cascading death";
[tests/test-connection.tlt](../tests/test-connection.tlt) asserts the
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
([tests/test-asset-manager.tlt](../tests/test-asset-manager.tlt)).

### Screens

The [ScreenManager](../screens/screen-manager.tlt) holds the current
screen but owns no screen: `show(next)` calls the current screen's
`hide`, which undoes what its `show` registered (a FormScreen's key
handler and its inputs' button, update, text and key registrations), and
then drops the reference. Who makes a screen decides how it ends:

- **Dropped and collected**: a WaitingScreen (`Session:join_game`,
  `GameDataRp`) and an OptionsMenuScreen (`UserMenuScreen:options`) are
  held by the manager alone and are collected once replaced; so is a
  user menu or a login screen once replaced, unless its owner dies first.
  A WaitingScreen has no
  `release`, so nothing runs; a form runs FormScreen's `release` with the
  reason `"unreachable"`. A collection does not order a form and its
  inputs (each hook has both as anchors, and neither owns the other), so
  the inputs may go first and unlink themselves from a form about to die,
  harmlessly.
- **Kept**: the client's ConnectingScreen is held by its disconnect
  callback and shown again on every disconnect; the server's ScreenSaver
  is shown once. Neither is ever destroyed.
- **Owned**: a GameScreen is made and owned by the session's `GameDataRp`
  (`GameScreen(...) @ self`) and destroyed by its own back entry, after
  that entry has shown a user menu; it owns its assets panel and that
  back entry (`@ self`), so a disconnect in the game destroys it with the
  session and its entry leaves the stack. On the client every user menu
  belongs to the logged-in period: `Session:show_user_menu` makes it
  `@ self._period` (at login, and from a game screen's back entry), so it
  ends with the logout or with the session; the login screen made at logout
  to the session (`LoginScreen(self._login) @ self`: destroyed with the
  session, or collected once a new login has replaced it, since nothing
  else refers to it). UserMenuScreen anchors the back entry it pushes for
  the options menu to itself (`push(...) @ self`), since the entry's
  callback shows it: when the screen dies, the entry dies too and leaves
  the stack, so no entry can show a menu of a dead session.

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
reads. When one of the two is destroyed (`lifetime.destroy`, or a
cascade from an owner), a hook runs after its anchor's destructor, among
its dependents ("Hooks: the `!@` operator"), and learns only the reason,
not which anchor died, so the flag tells the two orders apart: an input
that dies first is removed from the list while it is dying and still
findable; a form that dies first has said so, and the hooks do nothing
(the inputs live on); when the inputs are the form's dependents, one
cascade runs the form's `release` first and nothing is unlinked. A
collection gives no such order (see "Dropped and collected" above): the
inputs may go first and unlink themselves from a form about to die,
harmlessly
([tests/test-form-screen.tlt](../tests/test-form-screen.tlt) asserts the
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
never with timing. Tests write ownership with the extension's own syntax
(`x @ owner`, `f !@ x`). See
[tests/test-lifetime-class.tlt](../tests/test-lifetime-class.tlt) and the
whole tree in [tests/test-session.tlt](../tests/test-session.tlt).

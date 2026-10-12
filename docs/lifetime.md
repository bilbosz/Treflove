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

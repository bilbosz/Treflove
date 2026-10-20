# Object Lifetimes (lua-lifetime)

This branch replaces the hand-written `release()` chains of `master` with
ownership tracked by the lua-lifetime runtime, used as a plain library:
nothing is transpiled and no syntax is added. Where lua-lifetime's own
language writes `obj @ owner`, this code writes `obj:attach_lifetime(owner)`
(a method every class instance has) or, for an object that is not a class
instance, `lifetime.attach(obj, owner)`. The semantics are the library's
(its `docs/02-semantics.md`, "The library form").

## The vocabulary used

| Call | Meaning |
| --- | --- |
| `obj:attach_lifetime(owner, ...)` | `obj` dies when `owner` dies (or earlier, when nothing refers to it any more). Returns `obj`, so a construction and its anchoring chain: `self._login = Login(...):attach_lifetime(self)`. The anchors are `lifetime.attach`'s: several owners, `lifetime.pin(owner)`, `lifetime.reachable`. |
| `lifetime.attach(obj, owner)` | The same for an object that is not a class instance, such as a token. |
| `lifetime.hook(fn, a, b)` | `fn(reason)` runs when `a` or `b` dies, after that object's own `release()`. |
| `lifetime.token(name)` | An object that only names a span of time, to anchor to: the "logged in" period. |
| `lifetime.destroy(obj)` | Ends `obj` now: its `release(reason)`, then everything anchored to it, most recently attached first, then the tombstone. |
| `lifetime.block(function(scope) ... end)` | A block: what is attached or hooked to `scope` dies when the function returns, by an error too. |
| `lifetime.alive(obj)` | `false` for a tombstone. A dead object is not `nil`; indexing it raises. |
| `lifetime.dying(obj)` | `true` while `obj` is dying: its death decided, its tombstone not yet made. A hook on `(form, input)` asks it whether the form is going too. |

`release(reason)` is the destructor of every class instance (the class
system forwards the runtime's `__lifetime_destroy` to it). It is never called
by hand on this branch; the runtime calls it when the object's owner dies,
when `lifetime.destroy` is called on it, or when the collector finds it.
`reason` is `"anchor"`, `"destroy"`, `"unreachable"` or `"exit"`. Few
classes implement one: a tree node takes its subtree (`Tree`), a screen its
control tree (`Screen`), a connection frees its LÖVE threads and channels,
a remote procedure gives its handler slot back. Everything else is owned
through anchors or the control tree, and a registration on an `Event` or a
hit-tested manager ends by itself when its owner dies.

## Who owns what

```
Connection                      (a disconnect → lifetime.destroy;
└── Session                      love.quit → every connection in order)
    ├── Login
    │   ├── LoginRp
    │   └── LogoutRp
    ├── GameDataRp
    ├── UploadAssetRp, DownloadAssetRp, DownloadMissingAssetsRp
    ├── hook: clears the AssetManager's per-session entries
    ├── LoginScreen                     (client, from a logout to the next login)
    └── token "logged in"               (client)
        ├── UserMenuScreen              (shown again after the game)
        │   ├── OptionsMenuScreen       (made on the first visit, kept)
        │   └── back entry: return from the options (one per visit)
        ├── back entry: log out
        └── GameScreen                  (while in the game)
            ├── its control tree        (the panels, the preview area, the inputs)
            └── back entry: leave the game
```

The control tree is the other ownership: a destroyed control takes its
subtree with it, newest child first, each child destroyed inside its
parent's `release`, so a screen's panels, their inputs and the preview
area die with the screen without an anchor of their own, and a replaced
control (a notification line, a token property, a preview) is destroyed,
not detached and left to the collector.

The whole tree is driven end to end by the lifetimes test suite: a client and
a server in one process over fake channels, every step asserting the order of
the `release` calls it caused.

- **Disconnect**: one `lifetime.destroy(connection)` runs the connection's
  own `release` (channels, threads, the update event), then the session's
  tree newest first; every remote procedure's `release` unregisters its
  handler from the still usable, dying connection. The disconnect callbacks
  of the client and the server only clear their fields: a dead session is a
  tombstone, not `nil`.
- **Logout**: `lifetime.destroy` of the period token. The back entry leaves
  the stack, the menu screen (with its options screen, and the game screen
  if the user is in the game) hides itself and dies with its panels. The
  login screen shown next is the session's; the next login destroys it once
  the menu has replaced it.
- **The game**: the session builds the game screen under the period once the
  game data and its assets are in; the game screen's back entry shows the
  session's menu screen again (the same one) and destroys the game screen
  with its panels. Game data that arrives after a logout belongs to a period
  that is over and is ignored.
- **Back**: the backstack's `push(cb)` returns an entry with a hook that
  removes it from the stack when it dies, wherever it sits; the caller anchors
  it to what the entry is for (a screen, the period). `back()` destroys the
  top entry, then runs its callback. The old `pop(cb)` and its bookkeeping
  are gone, and so is the stale entry a logout left behind while the options
  screen was open on `master`.
- **Screens**: a screen destroyed while shown hides itself; the screen
  manager hooks the shown screen and forgets it when it dies, and discards
  the hook when another screen replaces it. Transient screens (connecting,
  waiting) are not anchored: they live on the default lifetime, like any
  object nobody owns, and have nothing to end at their death, since they
  register on the update event in `show` and unregister in `hide`.
- **Forms and inputs**: an input hooks `(form_screen, self)`. An input
  destroyed first (the token panel rebuilding its fields) unlinks itself
  from the form (a focused one loses the focus, so LÖVE text input is
  switched off) and leaves the control tree with its subtree; a form that
  is going too, as the root of the cascade or in it, is what the hook sees
  with `lifetime.dying(form_screen)`, and it does nothing then. The inputs
  of a dying form die with its control tree. Their registrations end by
  themselves: the events drop a dead owner, the button manager finds its
  buttons by walking the live tree, and a button it still holds under the
  pointer or pressed only triggers events nobody alive listens to.
  Unregistering an input from the button manager when its screen hides
  lets go of its button at once.
- **Events**: an owner the runtime has seen dies into a tombstone, which
  stays a weak key of an `Event` for one more collection (or longer, while
  something else holds it); `trigger` and `get_handler` treat a dead owner as
  gone and drop it.
- **A dropped file**: the one block scope, `lifetime.block`, closes the file
  on every exit path.
- **Program end**: `love.quit` removes every connection in order (each as a
  disconnect: the callback, then the cascade), while LÖVE's threads and
  channels are still usable, and then calls `lifetime.set_exiting(true)`, so
  whatever is left for the closing state reports `"exit"`.

## Rules of thumb on this branch

- Anchor an object where it is created, in the constructor of its owner:
  `self._x = X(...):attach_lifetime(self)`. A constructor returns a fresh
  object on the default lifetime and leaves anchoring to the caller.
- Only objects with something to clean up, or that own such objects, need an
  anchor. A control needs none to die with its parent: a destroyed node
  takes its subtree. Parent-child links are not anchors (a child may be
  detached and reparented), but a parent's death is a child's death.
- A `release(reason)` that overrides a base class's chains it, as `init`
  does: `Control.release(self, reason)`. Before writing one, ask whether a
  registry that drops dead owners, a hook, or the tree already does the
  work: a destructor is for what nothing else frees.
- A control that is replaced is destroyed (`lifetime.destroy`), not
  detached with `set_parent(nil)` and dropped: a detached subtree lives on
  until the collector finds it.
- Dead objects are tombstones. Clear the field or the table entry by hand
  where `master` cleared it after `release()`, or let a hook do it while the
  object is dying and still findable by identity (the back stack, the asset
  manager's per-session tables). A reference that may point at a tombstone
  is tested with `lifetime.alive` before use: a tree node does so for a
  parent that died first (an input the collector finds after its panel).
- A form screen is destroyed, never left to the collector: keep it in a field
  and destroy it when it is over, as the session does with its login screen.
  The collector finds the form and its inputs in one collection and runs the
  inputs' hooks against a form that is not dying yet. Those hooks reach the
  inputs' controls, whose LÖVE objects may already be freed: LuaJIT
  finalizes userdata newest first, and LÖVE frees an object in its `__gc`
  (`Cannot use object after it has been released.`). In general, a
  destructor or a hook that a death `"unreachable"` can run must not touch
  the LÖVE objects of what dies with it. Only the suite run inside LÖVE uses
  the real objects; the fake transform of plain LuaJIT stays usable.
- `lifetime.is_state(k)` skips the runtime's hidden field when iterating an
  anchored object with `pairs`; the table utilities (copies, merges, the
  emptiness test, the cyclic iterators, serialization) and `dump` already
  skip it.

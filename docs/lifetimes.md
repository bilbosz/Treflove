# Object Lifetimes (lua-lifetime)

This branch replaces the hand-written `release()` chains of `master` with
ownership tracked by [lua-lifetime](../lib/lua-lifetime/README.md), used as a
library (`local lifetime = require("lifetime")`): nothing is transpiled and
no syntax is added. Where a `.lt` file would write `obj @ owner`, this code
writes `obj:attach_lifetime(owner)` (every class instance has the method,
from [utils/class.lua](../utils/class.lua)) or, for an object that is not a
class instance, `lifetime.attach(obj, owner)`. The semantics are
[lib/lua-lifetime/docs/02-semantics.md](../lib/lua-lifetime/docs/02-semantics.md)
("The library form" names the calls used here).

## The vocabulary used

| Call | Meaning |
| --- | --- |
| `obj:attach_lifetime(owner, ...)` | `obj` dies when `owner` dies (or earlier, when nothing refers to it any more). Returns `obj`, so a construction and its anchoring chain: `self._login = Login(...):attach_lifetime(self)`. The anchors are `lifetime.attach`'s: several owners, `lifetime.pin(owner)`, `lifetime.reachable`. |
| `lifetime.attach(obj, owner)` | The same for an object that is not a class instance, such as a token: `lifetime.attach(lifetime.token("logged in"), self)`. |
| `lifetime.hook(fn, a, b)` | `fn(reason)` runs when `a` or `b` dies, after that object's own `release()`. |
| `lifetime.token(name)` | An object that only names a span of time, to anchor to: the "logged in" period. |
| `lifetime.destroy(obj)` | Ends `obj` now: its `release(reason)`, then everything anchored to it, most recently attached first, then the tombstone. |
| `lifetime.block(function(scope) ... end)` | A block: what is attached or hooked to `scope` dies when the function returns, by an error too. |
| `lifetime.alive(obj)` | `false` for a tombstone. A dead object is not `nil`; indexing it raises. |

`release(reason)` is the destructor of every class instance
([utils/class.lua](../utils/class.lua) forwards the runtime's `__destroy` to
it). It is never called by hand on this branch; the runtime calls it when
the object's owner dies, when `lifetime.destroy` is called on it, or when
the collector finds it. `reason` is `"anchor"`, `"destroy"`,
`"unreachable"` or `"exit"`.

## Who owns what

```
Connection                      (ConnectionManager:remove → lifetime.destroy)
└── Session
    ├── Login
    │   ├── LoginRp
    │   └── LogoutRp
    ├── GameDataRp
    ├── UploadAssetRp, DownloadAssetRp, DownloadMissingAssetsRp
    ├── hook: clears the AssetManager's per-session entries
    ├── LoginScreen                     (client, after a logout)
    └── token "logged in"               (client, Session._period)
        ├── UserMenuScreen
        │   ├── OptionsMenuScreen       (while open)
        │   └── back entry: return from the options
        ├── back entry: log out
        └── GameScreen                  (while in the game)
            ├── AssetsPanel
            │   └── PreviewArea         (release: file-drop registration)
            └── back entry: leave the game
```

- **Disconnect** ([networking/connection-manager.lua](../networking/connection-manager.lua)):
  one `lifetime.destroy(connection)` runs `Connection:release` (channels,
  threads, the update event), then the session's tree newest first; every
  remote procedure's `release` unregisters its handler from the still usable,
  dying connection. The client's and the server's disconnect callbacks only
  clear their fields: a dead session is a tombstone, not `nil`.
- **Logout** ([game/session.lua](../game/session.lua)): `lifetime.destroy`
  of the period token. The back entry leaves the stack, the menu screen (and
  the game screen, if the user is in the game) hides itself and dies with its
  panels; the login screen shown next lives as long as the session.
- **Back** ([utils/backstack-manager.lua](../utils/backstack-manager.lua)):
  `push(cb)` returns an entry with a hook that removes it from the stack when
  it dies, wherever it sits; the caller anchors it to what the entry is for.
  `back()` destroys the top entry, then runs its callback. The old `pop(cb)`
  and its bookkeeping (`Session._backstack_cb`) are gone, and so is the stale
  entry a logout left behind while the options screen was open on `master`.
- **Screens** ([screens/screen.lua](../screens/screen.lua),
  [screens/screen-manager.lua](../screens/screen-manager.lua)): a screen
  destroyed while shown hides itself; the screen manager hooks the shown
  screen and forgets it when it dies, and discards the hook when another
  screen replaces it. Transient screens (connecting, waiting) are not
  anchored: they live on the default lifetime, like any object nobody owns.
- **Forms and inputs** ([ui/input.lua](../ui/input.lua),
  [ui/form-screen.lua](../ui/form-screen.lua)): an input hooks
  `(form_screen, self)`. An input destroyed first (the token panel rebuilding
  its fields) unlinks itself from the form, ends its registrations
  (`TextInput:release`, `TextButton:release`) and leaves the control tree
  ([utils/tree.lua](../utils/tree.lua), `Tree:release`); a form destroyed
  first has set `is_released()`, and its hooks do nothing.
- **A dropped file** ([game/assets/preview-area/preview-area.lua](../game/assets/preview-area/preview-area.lua)):
  the one block scope, `lifetime.block`, closes the file on every exit path.
- **Program end** ([app/app.lua](../app/app.lua)): `love.quit` calls
  `lifetime.set_exiting(true)`, so the destructors LÖVE's closing state runs
  report `"exit"`.

## Rules of thumb on this branch

- Anchor an object where it is created, in the constructor of its owner:
  `self._x = X(...):attach_lifetime(self)`. A constructor returns a fresh
  object on the default lifetime and leaves anchoring to the caller.
- Only objects with something to clean up, or that own such objects, need an
  anchor. The control tree is still the tree: `Tree` parent-child links are
  not lifetimes, and most controls are never anchored.
- A `release(reason)` that overrides a base class's chains it, as `init`
  does: `Control.release(self, reason)`.
- Dead objects are tombstones. Clear the field or the table entry by hand
  where `master` cleared it after `release()`, or let a hook do it while the
  object is dying and still findable by identity (the back stack, the asset
  manager's per-session tables).
- `lifetime.is_state(k)` skips the runtime's hidden field when iterating an
  anchored object with `pairs`; `table.to_string` already skips it (table
  keys are not serialized).

# Architecture

## Dual-Mode Bootstrap

[main.lua](../main.lua) parses arguments and instantiates either Client or Server:
- **Client** ([app/client.tlt](../app/client.tlt)): Full UI application with multiple event managers (pointer, keyboard, wheel, button, text, file-drop, resize), screen manager, connection manager, asset manager, backstack navigation, notification system, and session management
- **Server** ([app/server.tlt](../app/server.tlt)): Can run headless or with a screen saver, manages multiple sessions (one per connection), persists game state to `save.lua` using human-readable serialization

Both inherit from [App](../app/app.tlt) and register LÖVE callbacks.

## Custom Class System

The project implements a custom class system in [utils/class.tlt](../utils/class.tlt) with **multiple inheritance** support (typed as described in [types.md](types.md), "Classes"; `release` is the destructor, see [lifetime.md](lifetime.md)):

```teal
local MyClass: MyClass = class("MyClass", BaseClass1, BaseClass2)
```

Key functions:
- `class(name, ...)` - creates a new class with optional base classes
- `is_instance_of(obj, cls)` - type checking
- `get_class_name_of(obj)` - reflection
- `get_class_of(obj)` - get class table
- `assert_type(obj, typ)` - runtime validation

Classes define an `init` method that acts as a constructor (assigned, `MyClass.init = function(self: MyClass, ...) ... end`). Multiple inheritance merges methods from all base classes in reverse order. Every instance of a class with a `release` is registered with the lifetime runtime after `init`, and `release` runs when it dies.

## Global App Instance

The global `app` variable references either the Client or Server instance and is accessible everywhere. Check `app.is_client` or `app.is_server` to determine context. Many systems are accessed through app managers (e.g., `app.screen_manager`, `app.asset_manager`).

## Networking Architecture

Thread-based networking using LÖVE's threading system:

- **ConnectionManager** ([networking/connection-manager.tlt](../networking/connection-manager.tlt)): Tracks all connections, indexed by channels
- **Connection** ([networking/connection.tlt](../networking/connection.tlt)): Wraps a pair of channels (in/out) and threads for bidirectional communication
- **Connector** ([networking/connector.tlt](../networking/connector.tlt)): Establishes connections
- **RemoteProcedure** ([networking/remote-procedure.tlt](../networking/remote-procedure.tlt)): Base class for RPC pattern

Each connection spawns separate threads for sending and receiving. The thread scripts ([networking/detail/](../networking/detail/)) are `.tlt` modules too; each runs in a Lua state of its own, so the Connector starts them from `build/` (`love.thread.newThread("build/networking/detail/client-out.lua")`) and each puts `build/` first on its require path before requiring anything. The server maintains multiple connections simultaneously; the client maintains one connection to the server.

## Remote Procedure Pattern

RPCs inherit from RemoteProcedure and implement:
- `send_response(request)` - server-side handler that returns response data
- `receive_response(response)` - client-side handler that processes response
- `send_request(request, cb)` - initiates RPC call

The class name is used as the RPC identifier. Examples: LoginRp, UploadAssetRp, DownloadAssetRp.

## Session Management

[Session](../game/session.tlt) ties a connection to user state:
- Manages login/logout lifecycle via [Login](../login/login.tlt)
- Coordinates screen transitions (connecting → login → user menu → game)
- Integrates with asset manager and backstack navigation
- Owns its login, its procedures and, on the client, the logged-in period
  (a token owning every user menu and the logout back entry) and the login
  screen; it is anchored to its connection and dies when the connection is
  removed (the whole tree: [lifetime.md](lifetime.md), "The Tree")
- Server maintains `_sessions` table mapping Connection → Session
- **Note**: Client auto-logs in with hardcoded credentials "adam"/"krause" at [game/session.tlt:73](../game/session.tlt#L73)

## Ownership

Who owns what is written where an object is made, with the lua-lifetime
extension: `x @ owner` anchors `x` to its owner, `f !@ x` attaches a hook
that runs as `x` dies, and a class's `release` is its destructor. A
connection is a root of the ownership tree: its session is anchored to it,
and the session owns its login, its remote procedures and, on the client,
the logged-in period (a token owning every user menu and the logout back
entry) and the login screen; the game screen belongs to the session's
`GameDataRp`. Roots die by `lifetime.destroy`: the connection in
`ConnectionManager:remove`, the period on logout, a game screen by its own
back entry, a back entry in `BackstackManager:back`. The runtime then runs
the owner's `release` first and its dependents most recently attached
first. Hooks unlink objects from lists as they die (an input from its
form, a back entry from the stack, a session's entries from the
AssetManager). At program end `App` sets `love.quit` to announce it
(`lifetime.set_exiting(true)`), and what the closing state finalizes runs
its cascade. The control tree is not an ownership tree. The whole tree,
the order of every teardown and the rules: [lifetime.md](lifetime.md),
"The Tree".

## Event System

Events are composed, not inherited: a single [Event](../events/event.tlt) class is instantiated by managers (or by `app` directly) and consumers register handlers on it:
- `Event` API: `register(owner, handler)`, `unregister(owner)`, `release()`, `trigger(...)`, `get_handler(owner)`; handlers are called as `handler(owner, ...)`
- Owners are weak keys, so a collected owner drops out without unregistering (an owner the lifetime runtime has seen stays a weak key as a tombstone for one more collection, so `trigger` and `get_handler` skip and drop a dead owner); handlers are held strongly, so register methods, never closures capturing the owner: `app.update_event:register(self, self.on_update)`
- Registering during a trigger is deferred until it finishes; unregistering takes effect immediately
- Unregistering is optional, since owners are weak keys; consumers with an explicit lifecycle unregister when it ends - Connection and PreviewArea in `release()`, FormScreen in `hide()`, Input, TextInput and TextButton in `on_screen_hide()`, TextInput and TextButton also in `on_focus_lost()`

Events by source:
- Broadcast events: `app.update_event` (dt), `app.wheel_event` (x, y, client only), `app.resize_manager.resized` (width, height)
- [KeyboardManager](../events/keyboard.tlt): `key_pressed`/`key_released` (key), always delivered, also during text input (backstack, form navigation, button activation)
- [PointerEventManager](../events/pointer-event.tlt) (`pointer_down/up/move`) and [FileSystemDropEventManager](../events/file-drop-event.tlt) (`file_dropped`): owners are Controls; dispatch is hit-tested by [hit-test.tlt](../events/hit-test.tlt) instead of `trigger` - only visible controls under the point, top-most first, a falsy return consumes the event, `set_receive_through` opts a control into events consumed above it
- [ButtonEventManager](../ui/button-event.tlt): drives the [Button](../ui/button.tlt) helper owned by every [Input](../ui/input.tlt) (hover/selection state, events `clicked`, `selected`, `unselected`, `pointer_entered`, `pointer_left`); controls register with `register(ctrl, button)`; an Input removes itself from its [FormScreen](../ui/form-screen.tlt) through a hook when it dies ([lifetime.md](lifetime.md), "Screens")
- [TextEventManager](../ui/text-event.tlt): `text_appended`, `characters_removed`, `word_removed`, `entered` go to the focused text field, which applies them to its [TextBuffer](../ui/text-buffer.tlt) helper (UTF-8 aware editing, events `edited`, `removed_empty`); `set_text_input`/`is_text_input` toggle LÖVE text input

Client creates the managers in its `init` and wires them to LÖVE callbacks in `register_love_callbacks`: `dispatch_*` methods for keyboard and pointer input, `text_input`/`key_pressed` on TextEventManager, `file_drop`, `resize`, and `wheel_event:trigger`.

## UI Control Hierarchy

[Control](../controls/control.tlt) is the base class for all UI elements:
- Manages parent-child relationships via `add_child`/`remove_child`
- Handles transforms (position, scale, rotation)
- Computes axis-aligned bounding boxes (AABBs) for hit testing
- Propagates events down the hierarchy
- Can intercept pointer events

Specialized controls:
- [DrawableControl](../controls/drawable-control.tlt): Adds rendering
- Primitives: Rectangle, Circle, Text, Image
- [ClippingMask](../controls/clipping-mask.tlt): Clips children to rectangular bounds

Higher-level UI components in [ui/](../ui/) like Panel, TextButton, Input, NumberInput build on these primitives.

## Screen Management

[ScreenManager](../screens/screen-manager.tlt) manages active screen via `show(screen)`: it hides the current screen and shows the next, holding but not owning it (who owns each screen and destroys it: [lifetime.md](lifetime.md), "Screens"). Screens are full-screen UI containers. Key screens:
- ConnectingScreen - connection status
- LoginScreen - authentication
- UserMenuScreen - post-login menu
- GameScreen - main game view
- WaitingScreen - loading states
- ScreenSaver - server screen when headless

## Asset Management

[AssetManager](../data/asset-manager.tlt):
- Tracks assets per session
- Downloads missing assets from server on demand
- Handles asset uploads to server
- [Asset](../data/asset.tlt) wraps LÖVE's filesystem operations

RPCs: DownloadAssetRp, DownloadMissingAssetsRp, UploadAssetRp

## Data Persistence

Server persists game state to `save.lua` in human-readable format:
- `table_utils.to_string()` serializes Lua tables to string ([utils/table.tlt](../utils/table.tlt))
- `table_utils.from_string()` deserializes back to tables
- `Server:save_data()` writes to file
- `Server:_load_data()` reads on startup

The [server/](../server/) directory contains server data, not source code: [server/save.lua](../server/save.lua) (persisted game state) and `server/assets/` (game assets like tokens and the world map).

## Backstack Navigation

[BackstackManager](../utils/backstack-manager.tlt) maintains a stack of callbacks for back navigation (similar to browser history). `push(cb)` returns an entry that removes itself from the stack when it dies; the caller anchors or destroys it ([lifetime.md](lifetime.md), "Back Navigation"). When user presses back, the top entry is destroyed and its callback invoked.

## Key Design Patterns

**Shared Client/Server Code**: Classes in `data/`, `controls/`, `networking/` work in both contexts. Use `app.is_client` or `app.is_server` to branch behavior.

**Manager Pattern**: Centralized managers coordinate subsystems (ConnectionManager, ScreenManager, AssetManager, event managers, etc.).

**Composed Events**: Managers expose `Event` fields; components register their methods on them instead of inheriting listener classes.

**Remote Procedures**: Request-response pattern over network connections using class names as identifiers.

**Resource Cleanup**: A class's `release(reason)` is its destructor: `class()` forwards the instance's `__destroy` to it, and the lifetime runtime runs it once when the object dies - destroyed (`lifetime.destroy`), with its owner (a cascade), collected, or at program end - with the reason. It undoes only what the object holds itself (threads and channels, event registrations, a request handler); what the object owns is anchored to it and dies in the cascade after it, so a destructor never releases its dependents, and no call site releases an object someone else owns ([lifetime.md](lifetime.md), "Ownership").

## LÖVE Framework Integration

- Entry: [main.lua](../main.lua)
- Config: [conf.lua](../conf.lua)
- Callbacks registered in `App:register_love_callbacks()` and overridden in Client/Server
- Client uses love.graphics, love.window, love.keyboard, love.mouse, love.touch
- Both use love.thread (threads and channels) for networking
- Server can run headless (no graphics) or with minimal UI

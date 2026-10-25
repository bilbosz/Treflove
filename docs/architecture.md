# Architecture

## Dual-Mode Bootstrap

The entry point starts the debugger when VS Code attached one (see
[development.md](development.md#debugging)), parses the command line and
instantiates either the Client or the Server:
- **Client**: the full UI application, with the event managers (pointer,
  keyboard, wheel, button, text, file-drop, resize), the screen manager, the
  connection manager, the asset manager, backstack navigation, notifications
  and session management
- **Server**: runs headless or with a screen saver, manages one session per
  connection, persists the game state in human-readable form

Both inherit from `App`, which registers the LÖVE callbacks.

## Custom Class System

A custom class system with **multiple inheritance**:

```lua
local MyClass = class("MyClass", BaseClass1, BaseClass2)
```

- `class(name, ...)` creates a class with optional bases; `init` is the
  constructor; instances are made with `ClassName(...)`
- `is_instance_of(obj, cls)`, `get_class_name_of(obj)`, `get_class_of(obj)`
  for reflection; `assert_type(obj, typ)` for runtime validation
- Base methods are merged into the class at creation, in reverse order of the
  bases, so a base must be complete before a class derives from it
- Every instance also has the methods of `Object`, the type-level base of
  every root class (`---@class X: Object`): `attach_lifetime(...)`, which
  anchors the instance with lua-lifetime and returns it, so
  `X(...):attach_lifetime(owner)` chains

## Global App Instance

The global `app` is the Client or the Server instance and is accessible
everywhere. `app.is_client` and `app.is_server` tell the context. Subsystems
are reached through the app's managers (`app.screen_manager`,
`app.asset_manager`, ...).

## Networking

ENet (the `enet` module LÖVE bundles: reliable, ordered packets over UDP)
on one LÖVE thread per side, talking to the main thread over channels:

- **Connector**: owns the host thread (`networking/detail/server-host.lua`
  or `client-host.lua`), starts it, starts it again once it ends (after a
  retry time, logging the error it died with) and turns what it reports
  into connections: `"a"` (a peer connected, with its in and out channels)
  and `"d"` (a peer disconnected, with its in channel)
- **ConnectionManager**: tracks the connections, indexed by their in
  channel; removes one when its peer is lost and, at program end, all of
  them in order
- **Connection**: a pair of channels (in: what the peer sent, out: what to
  send it), the FIFO of the response handlers and the request handlers by
  procedure name; its `release` pushes `false` on the out channel, the
  request to disconnect the peer, and frees the channels
- **RemoteProcedure**: the base of the request-response pattern

The host thread services its ENet host in a loop (`host:service` with a
short timeout, then every out channel, then the stop channel): a received
packet goes on the peer's in channel, a message on an out channel is sent
reliably, `false` disconnects the peer. The server's host listens on the
address and port and holds up to `NETWORK_PEER_LIMIT` peers, each with
channels of its own; the client's host connects out, waits
`NETWORK_CONNECT_TIMEOUT_MS` for the connection and ends when the peer is
gone, so the connector reconnects. ENet fragments and reassembles large
packets (an asset upload is one packet) and gives a peer up after
`NETWORK_PEER_TIMEOUT_MS` of silence (a process that died, a network that
went away). At program end `ConnectionManager:remove_all` destroys every
connection and stops the connector: the host thread disconnects its peers,
which hear of it at once, and the main thread waits for the
acknowledgements, at most `NETWORK_DISCONNECT_TIMEOUT_MS`.

## Remote Procedures

A remote procedure inherits from `RemoteProcedure` and implements
`send_response(request)` (the server-side handler, returns the response
data), `receive_response(response)` (the client-side handler) and calls
`send_request(request, cb)` to start a call. The class name is the wire
identifier (`LoginRp`, `UploadAssetRp`, `DownloadAssetRp`, ...).

## Session Management

A `Session` ties a connection to a user:
- Manages the login and logout lifecycle through a `Login`
- Coordinates the screen transitions (connecting → login → user menu → game,
  and the assets workspace over the menu or the game)
- Integrates with the asset manager and backstack navigation
- Holds the user's `PermissionSet` while logged in: the server resolves it
  from the game data at login, the client receives the grants with the game
  data; see [permissions.md](permissions.md)
- The server keeps a map from connection to session
- Is anchored to its connection and owns its login, its remote procedures
  and, on the client, the "logged in" token that owns the menu and game
  screens; the game screen and the assets workspace are built under the
  token and destroyed on the way back, see [lifetimes.md](lifetimes.md)
- **Note**: the client auto-logs in with hardcoded credentials
  ("adam"/"krause") when its session is created

## Event System

Events are composed, not inherited: a single `Event` class is instantiated by
managers (or by `app` directly) and consumers register handlers on it:
- `Event` API: `register(owner, handler)`, `unregister(owner)`, `clear()`,
  `trigger(...)`, `get_handler(owner)`; handlers are called as
  `handler(owner, ...)`
- Owners are weak keys, so a collected owner drops out without
  unregistering; an owner lua-lifetime has seen dies into a tombstone, which
  stays a weak key for one more collection, so `trigger` and `get_handler`
  skip and drop a dead owner. Handlers are held strongly, so register
  methods, never closures capturing the owner:
  `app.update_event:register(self, self.on_update)`
- Registering during a trigger is deferred until it finishes; unregistering
  takes effect immediately
- Unregistering is optional, since owners are weak keys and a dead owner is
  dropped; consumers with an explicit lifecycle unregister when it ends (a
  connection in `release()`, a form screen in `hide()`, inputs in
  `on_screen_hide()` and `on_focus_lost()`)

Events by source:
- Broadcast events: `app.update_event` (dt), `app.wheel_event` (x, y, client
  only; a consumer asks its screen `is_showed()` and the pointer manager
  for the position, so a page under the workspace keeps its zoom),
  `app.resize_manager.resized` (width, height)
- `KeyboardManager`: `key_pressed`/`key_released` (key), always delivered,
  also during text input (backstack, form navigation, button activation)
- `PointerEventManager` (`pointer_down/up/move`) and
  `FileSystemDropEventManager` (`file_dropped`): owners are Controls; dispatch
  is hit-tested instead of broadcast: only visible controls under the point,
  top-most first; a falsy return consumes the event; `set_receive_through`
  opts a control into events consumed above it. A control is under the
  point when its bounds are, where it and its descendants draw; a clipping
  control's bounds are its box, so what is clipped from view is not hit. A
  control that took a press may `capture(ctrl, id)` it: the moves and the
  release of that press then go to it alone, hit-tested or not, until the
  release (or `release_capture`); every press has a captor of its own, and
  a captor that died lets go. The page and the scroll view hold their drags
  this way, so a drag goes on outside them and ends wherever it is released
- `ButtonEventManager`: drives the `Button` helper owned by every `Input`
  (hover and selection state; events `clicked`, `selected`, `unselected`,
  `pointer_entered`, `pointer_left`); controls register with
  `register(ctrl, button)`; `unregister(ctrl)` lets go of a button under the
  pointer or pressed (it is unselected and left at once, never driven later)
- `TextEventManager`: `text_appended`, `characters_removed`, `word_removed`,
  `entered` go to the focused text field, which applies them to its
  `TextBuffer` helper (UTF-8 aware editing; events `edited`,
  `removed_empty`); `set_text_input`/`is_text_input` toggle LÖVE text input

The client creates the managers in its constructor and wires them to the
LÖVE callbacks when it registers them.

## UI Control Hierarchy

`Control` is the base of every UI element: parent-child relationships
(`add_child`/`remove_child`), transforms (position, scale, rotation),
axis-aligned bounding boxes for hit testing. `DrawableControl` adds
rendering; the primitives are Rectangle, Circle, Text and Image;
`ClippingRectangle` and `ClippingMask` clip their children to their box,
nested clips intersect, and their bounds are the box, so what is clipped is
neither drawn nor hit. Higher-level components (Panel, TextButton, Input,
TextInput, NumberInput, ScrollView) build on them. `ScrollView` is a
viewport over a content control larger than itself (`get_content`,
`set_content_size`): the content is dragged with `SCROLL_VIEW_DRAG_BUTTON`,
press, drag, release, no further than its edges, holding the pointer
meanwhile. Optional indicators of a fixed size (`SCROLL_VIEW_INDICATOR_*`)
along the overflowed edges mark where the view is. The token panel, the
assets panel and the workspace's details keep what is above their buttons
in one.
A destroyed control takes its subtree with it, newest child first; a screen
destroys its control tree, see [lifetimes.md](lifetimes.md).

The graphics folder holds the two texture systems, the fonts module and the
images module, both caches over LÖVE objects that the controls draw with.

`Text` lays out in model units with a reference font (the fonts module's
`REFERENCE_SIZE`, 80) and, when drawn, rasterizes at the pixel size its
global transform gives: the fonts module keeps one `love.Font` per kind
(`fonts.Kind`, display or user input) and integer pixel size. Axis-aligned
text is drawn one glyph texel per screen pixel at a whole-pixel position;
rotated text keeps its transform and scales the glyphs inside it.

`Image` draws a `love.Image` the images module made with its mipmap chain,
filtered linearly within and between the levels, so a downscaled image (a
token avatar, a zoomed-out page) samples the level of its on-screen size
instead of skipping texels; the module keeps one image per file path, which
the asset manager forgets when it writes the file again. An axis-aligned
image is drawn at a whole-pixel position and, when its scale is within half
a pixel of one texel per screen pixel, exactly at that; a rotated image
keeps its transform.

## Screen Management

`ScreenManager` shows one screen at a time (`show(screen)`); screens are
full-screen UI containers: ConnectingScreen, LoginScreen, UserMenuScreen,
OptionsMenuScreen, GameScreen, AssetsWorkspaceScreen, WaitingScreen, and
ScreenSaver for a server with a window.

## Asset Management

`AssetManager` tracks assets per session (on the client, the procedures used
are its own session's), downloads missing assets from the server on demand,
uploads new ones and changes the store: a folder (`make_folder`), a move
(`move`, a file or a folder with everything under it) and a removal
(`remove`), each validated and refused with a reason for the user. `Asset`
wraps LÖVE's filesystem: one path, read, written, moved, removed, and the
path helpers (`check_path`, `get_name`, `get_parent`, `join`, `is_under`)
and the listing of the whole store (`Asset.list`, parents before their
content). The procedures are DownloadAssetRp, DownloadMissingAssetsRp,
UploadAssetRp, ListAssetsRp, CreateAssetFolderRp, RenameAssetRp and
DeleteAssetRp; the listing needs `read` on `assets`, every change `write`
on `assets`. A rename keeps the game pointing at the renamed assets (the
pages' images, the tokens' image properties: `asset_usage`), a delete is
refused while the game uses the asset or something under the folder. The
client mirrors a rename and a delete on its own copies.

The assets workspace (`game/assets/workspace/`) is the store as a file
manager, opened from the user menu or from the game's assets panel:
`AssetList` shows one folder, folders first, scrolled with the wheel, a
whole-row button (`AssetListRow`) per entry; `AssetDetails` holds the
preview (the drop target), the name field the actions use, the type and the
action buttons; `AssetsWorkspaceScreen` keeps the state (the listing, the
shown folder, the selection, the dropped file), asks the server and gates
the buttons: a selected folder can be opened (a second click too) and
deleted, a selected entry renamed to a free name, a free name made a folder,
a dropped file uploaded under the typed name into the shown folder (over a
file, never over a folder). A read-only button is dimmed and skipped by the
pointer and by Tab. What the server refuses is notified with its reason; the
listing is asked again after every change.

## Permissions

Groups, grants and their enforcement are data in the game state and one
module (`permissions`) plus one class (`PermissionSet`) used on both sides:
the server filters the game data it sends by `read`, lists the assets only
with `read:assets`, refuses uploads, folders, renames and deletes without
`write:assets`; the client gates editing and dragging of tokens, the upload
button and the workspace's actions. See [permissions.md](permissions.md).

## Data Persistence

The server persists the game state as a human-readable Lua table:
`table.to_string()` serializes (a string on one line, its quotes and
backslashes escaped), `table.from_string()` deserializes; the
server writes on `save_data()` and reads at startup. The state holds the
pages, tokens and token properties, the players and the permission groups
(`GameData` in `game/game-data-rp.lua`). The server's data
directory holds the persisted state and the game assets (tokens, the world
map); it is data, not source code.

## Backstack Navigation

`BackstackManager` keeps a stack of entries for back navigation (like a
browser history). `push(cb)` returns the entry, which the caller anchors to
what it is for (a screen, the logged-in token); an entry leaves the stack
when it dies. On the back key the top entry is destroyed and its callback
invoked. The session pushes the entries of the screens it opens (the game,
the assets workspace) once, when it opens them, so a screen shown again
(the game after the workspace) gets no second entry.

## Key Design Patterns

- **Shared client/server code**: data, controls and networking classes work
  in both contexts; branch on `app.is_client`/`app.is_server`
- **Managers**: centralized managers coordinate the subsystems
- **Composed events**: managers expose `Event` fields; components register
  their methods on them instead of inheriting listener classes
- **Remote procedures**: request-response over a connection, the class name
  as the identifier
- **Resource cleanup**: `release(reason)` is the destructor lua-lifetime runs
  when the object's owner dies, when `lifetime.destroy` is called on it, or
  when the collector finds it; never called by hand, and written only for
  what nothing else frees (a tree node's subtree, a screen's tree, a
  connection's peer and channels, a procedure's handler slot). Ownership is
  declared where objects are created: `X(...):attach_lifetime(owner)`, or by
  the control tree. See [lifetimes.md](lifetimes.md)

## LÖVE Framework Integration

- The LÖVE callbacks are registered by `App` and extended by Client and
  Server; `love.quit` removes every connection in order and then tells
  lua-lifetime the program is ending
- The client uses love.graphics, love.window, love.keyboard, love.mouse and
  love.touch; both sides use love.thread, love.channel and the bundled
  `enet` module for networking
- The server can run headless (no graphics) or with a minimal UI

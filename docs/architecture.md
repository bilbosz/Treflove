# Architecture

## Dual-Mode Bootstrap

The entry point starts the debugger when VS Code attached one (see
[development.md](development.md#debugging)), parses the command line and
instantiates the Client, the Server, the console command or the Monitor:
- **Client**: the full UI application, with the event managers (pointer,
  keyboard, wheel, button, text, file-drop, resize), the screen manager, the
  connection manager, the asset manager, backstack navigation, notifications
  and session management
- **Server**: runs headless or with a screen saver, holds the accounts and
  every game of its root (one process, any number of games), manages one
  session per connection, persists the accounts and each game in
  human-readable form
- **Console** (`love . console`): the console client as a command, no
  window, a `love.run` of its own; **Monitor** (`love . monitor`): a window
  showing the watches and the log of one or more consoles

The Client, the Server and the Monitor inherit from `App`, which registers
the LÖVE callbacks and installs the project's own main loop (`MainLoop`,
the `love.run`); the Client and the Monitor through `UiApp`, which holds
the UI managers and wires the input callbacks. The command line takes
options after the port (`--scenario`, `--console`, `--server-console`,
`--identity`, `--fixture`, `--headless`): see
[scenarios-and-console.md](scenarios-and-console.md).

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

The connection is symmetric: a received message whose source is the
receiver's own is a response, any other a request dispatched to the handler
registered for its id, and every procedure is built on both sides. So a
procedure the server starts works the same way with the roles swapped:
`TokenChangedRp` is sent by the server with `send_request` to every other
session in the game, its `send_response` is the client's handler, which
applies the change and answers an empty acknowledgement, and the server's
`receive_response` has nothing to do. The request-response pair the client
starts, `UpdateTokenRp`, and the push are described under [Tokens](#tokens).

A request whose id has no handler on the receiving side (a procedure one
build has and the other has not) does not kill the receiver: the
connection logs it and answers a refusal body (`UnknownProcedureResponse`:
`success = false`, the error naming the procedure), so the sender's queue
of response handlers stays in step and its `receive_response` sees a
refusal; the peer stays connected. A push the server starts
(`TokenChangedRp`, `TokenCreatedRp`, `TokenDeletedRp`) is built on both
sides like every procedure, so a client can send it to the server: its
`send_response` there logs the request and answers an empty
acknowledgement instead of asserting.

## Session Management

A `Session` ties a connection to a user:
- Manages the login and logout lifecycle through a `Login`, and the
  creation of an account (`sign_up`: `CreateAccountRp`, then the login
  with the same credentials)
- Coordinates the screen transitions (connecting → login, or the sign-up
  over it → user menu → the Games menu → the games to join, the new game
  or the games to delete over it, the question over those → game, the
  new token screen over it, and the assets workspace over the game or the
  new token screen)
- Integrates with the asset manager and backstack navigation
- Holds the user's `PermissionSet` while in a game: the server resolves it
  from the game's data when the session selects the game
  (`Session:select_game`), the client receives the grants with the game
  data; see [permissions.md](permissions.md)
- On the server, holds the game the session is in (`Session:get_game`),
  at most one at a time; the server keeps a map from connection to session,
  and the game keeps the live sessions in it (`Game:get_sessions`, weak
  keys: the session registers when it selects the game and leaves at the
  logout, a dead one drops out), which is who a change is pushed to
- On the client, sends a token change (`Session:update_token(id, changes,
  new_id)`: the page after a drag, the token panel after Apply or an image
  chosen in the workspace) and applies the server's entry to its copy and
  to the shown page (`Session:apply_token(id, new_id, token)`: the one path
  a push, a refusal's restore and a success's convergence take)
- On the client, creates a token (`Session:create_token(id, token, cb)`:
  `CreateTokenRp` with the shown page) and deletes one
  (`Session:delete_token(id)`: `DeleteTokenRp`); both are applied when the
  server answers, through the path its push takes too
  (`Session:apply_token_created(id, page, token)`,
  `Session:apply_token_deleted(id)`), and a refusal is notified
- On the client, shows the new token screen over the game
  (`show_new_token`, `close_new_token`)
- Sends a change to an entry of the game's data (`Session:update_entry`,
  `create_entry`, `delete_entry`: a page, a group, a player, a token
  property or the shown page, see [Entries](#entries)) and applies the
  server's answer and its pushes (`apply_entry`, `apply_entry_created`,
  `apply_entry_deleted`); receives its grants again when they change
  (`apply_grants`)
- Is anchored to its connection and owns its login, its remote procedures
  and, on the client, the "logged in" token that owns the menu and game
  screens; the Games menu, the games to join, the new game screen, the
  games to delete and the question about one, the game screen and the
  assets workspace are built under the token and destroyed on the way
  back, see [lifetimes.md](lifetimes.md)
- The client shows the session's login screen on connect
  (`Session:show_login`); a login lands on the user menu, whose Games
  entry opens the Games menu (`show_games_menu`, `GamesMenuScreen`), with
  Join, Create, Delete and Back: Join lists the server's games
  (`show_join_game`, `JoinGameScreen`), a click joining one
  (`join_game(id)`), Create opens the new game screen (`show_new_game`),
  which creates a game and joins it (`create_game`), and Delete lists the
  games the user may delete
  (`show_delete_game`, `DeleteGameScreen`, from the same listing), a click
  asking `Are you sure to delete "<name>" game?` with Yes and No
  (`confirm_delete_game(id, name)`, `ConfirmDeleteGameScreen`), Yes
  deleting it (`delete_game(id)`), by the user or by a scenario
  ([scenarios-and-console.md](scenarios-and-console.md))
- Holds, on the client, the id of the game whose data it holds
  (`set_game_data` at the game data response, `get_game_id`) and drops
  that game when the server says it is deleted (`apply_game_deleted`: the
  notification, the way out of the game screen when the client is in it,
  then `clear_game_data`: `app.data`, the grants, the store and the
  client's copies of the game's assets); on the server, leaves the
  selected game (`deselect_game`) when it is deleted or at the logout

## Accounts and Games

The server's root (`s/` in its save directory) holds the accounts and the
games, each game with a store of its own:

```
s/accounts.lua                 by login: the display name and the auth (the server-side hash)
s/games/<id>/save.lua          one game's GameData
s/games/<id>/assets/...        that game's asset store
```

- `Accounts` (`data/accounts.lua`) reads and writes the accounts file:
  `find_by_auth` is what the login procedure asks, `create` what the
  sign-up asks, after the checks the client ran too (`check_login`: up to
  32 characters of `[%w_.-]`, not starting with `@`; `check_name`,
  `check_password`: not empty). The password hashing is unchanged: the
  client hashes the password with its salt, the server hashes the result
  with its own, and the account holds the second hash.
- `Games` (`data/games.lua`) is the games directory: `list` the ids (the
  directories holding a `save.lua`), `get` a `Game` (`game/game.lua`:
  the id, the `GameData`, its `AssetStore`, `save`, `add_player`,
  `allows`: whether a login is a player whose grants in it allow an
  action, resolved from the data now), loaded
  once and kept, `delete` one (its directory removed with the save and
  the store, the id free again), `create` a new one from the template
  (`server/template/`: a table page of 20 by 15 meters with one token,
  `Hero`, and the groups `master` and `player`) seeded into
  `s/games/<id>/` with the name given, the creator in `master` and as
  the owner of `Hero`. The id is the name's slug (`Games.make_id`: lower
  case, runs of other characters become one `-`); a taken id refuses the
  creation.
- The procedures: `CreateAccountRp` (login, name, the client hash),
  `ListGamesRp` (every game by id, name, whether the session's user is a
  member and whether they may delete it, `Game:allows(login, "write",
  "game")`, for a logged-in session), `CreateGameRp` (the name; the id
  back), `GameDataRp` (the id of the game to join: the server selects it
  for the session, adds the user to its `players` in the group `player`
  when absent, since games are open to every account, resolves the
  permissions and answers with the filtered data and the grants, or with
  `success = false` for an unknown id), `DeleteGameRp` (the id: the
  server refuses a session not logged in, an unknown id and a user who is
  not a player of the game or whose grants in it lack `write` on `game`,
  each with a reason; otherwise every live session in the game leaves it,
  the other ones are pushed `GameDeletedRp` with the id and the name, the
  directory is removed and the answer carries the id and the name). The
  deleter's answer and the push take one path on the client,
  `Session:apply_game_deleted`.
- The server starts from scratch: a root with nothing under it has no
  accounts and no games; `Accounts` writes `s/accounts.lua` at the first
  sign-up and `Games` makes `s/games/<id>` at the first game. The root is
  kept across restarts and nothing in the program resets it. `--fixture`,
  the scenario tooling
  ([scenarios-and-console.md](scenarios-and-console.md)), empties the
  root and seeds it from the fixture given, every time, and is refused
  without `--identity`, so it never lands on the default save directory.

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
- Broadcast events: `app.update_event` (dt),
  `app.resize_manager.resized` (width, height)
- `KeyboardManager`: `key_pressed`/`key_released` (key), always delivered,
  also during text input (backstack, form navigation, button activation).
  It remembers the keys it dispatched as pressed and not yet released, so
  `is_key_down(key)` answers from the events first and from
  `love.keyboard` second: a scenario, which pushes key events, holds a
  modifier as a user does. `is_ctrl_down()` (Ctrl, and Cmd on macOS) and
  `is_shift_down()` are what the consumers ask (the form's Shift+Tab, the
  page's selection keys, the text event manager); a lost window focus
  forgets every tracked key (`release_all`)
- `PointerEventManager` (`pointer_down/up/move`, and `wheel`, dispatched
  at the pointer's position with the movement, `(x, y, dx, dy)`, `dy`
  positive away from the user, with a receive-through set of its own,
  `set_wheel_receive_through`, since the page receives the pointer events
  through and must not zoom under a list) and
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
  pointer or pressed (it is unselected and left at once, never driven later).
  The button under the point is the top-most one, the last in tree order
  among the visible, hit, non-read-only controls holding a button (a child
  after its parent, a later sibling after an earlier one), the control the
  pointer dispatch would call first, so a list opened over other inputs
  takes the hover and the click
- `TextEventManager`: `text_appended` (the text typed; dropped while Ctrl
  is held) and `commanded` (one of `TextEventManager.Command`: a move by a
  character, a word or to the line's end, with Shift extending the
  selection; a delete backward or forward, by a character or a word;
  select all; copy, cut, paste; undo, redo; enter) go to the focused text
  field, which applies them to its `TextBuffer` (UTF-8 aware; the caret,
  the selection and the history of edits; events `edited`, `moved`,
  `removed_empty`). The keys: the arrows, Home and End, Backspace and
  Delete, Ctrl for a word, Ctrl+A, Ctrl+C/X/V, Ctrl+Z and Ctrl+Shift+Z or
  Ctrl+Y, Return. The manager also wraps the clipboard (`set_clipboard`,
  `get_clipboard`: the text flattened to one line, empty when it is not
  UTF-8); `set_text_input`/`is_text_input` toggle LÖVE text input

The client creates the managers in its constructor and wires them to the
LÖVE callbacks when it registers them.

## UI Control Hierarchy

`Control` is the base of every UI element: parent-child relationships
(`add_child`/`remove_child`), transforms (position, scale, rotation),
axis-aligned bounding boxes for hit testing. `DrawableControl` adds
rendering; the primitives are Rectangle, Circle, Triangle, Text and
Image; a border-only `Rectangle` draws its line inside its box.
`ClippingRectangle` and `ClippingMask` clip their children to their box
(every pixel the box touches), nested clips intersect, and their bounds are
the box, so what is clipped is neither drawn nor hit. Higher-level components (Panel, TextButton, Input,
TextInput, NumberInput, SelectionBox, ScrollView) build on them. `ScrollView` is a
viewport over a content control larger than itself (`get_content`,
`set_content_size`): the content is dragged with `SCROLL_VIEW_DRAG_BUTTON`,
press, drag, release, no further than its edges, holding the pointer
meanwhile, and scrolled with the wheel over it by `SCROLL_VIEW_WHEEL_STEP`
units a notch (`set_wheel_step` for another step: the monitor's panes by
lines, a selection box's list by `SELECTION_BOX_WHEEL_ROWS` rows),
consumed whether or not the content overflows, so the page under a side
panel's list keeps its zoom; a hover or a highlight follows the pointer
only on a move, so what scrolled under a still pointer keeps its state
until the next move, as under a drag.
Optional indicators of a fixed size (`SCROLL_VIEW_INDICATOR_*`)
along the overflowed edges mark where the view is. The token panel and the
workspace's details keep what is above their buttons in one, the
workspace's usage list its buttons.
A destroyed control takes its subtree with it, newest child first; a screen
destroys its control tree, see [lifetimes.md](lifetimes.md).

The graphics folder holds the two texture systems, the fonts module and the
images module, both caches over LÖVE objects that the controls draw with.

`Text` lays out in model units with a reference font (the fonts module's
`REFERENCE_SIZE`, 80) and, when drawn, rasterizes at the pixel size its
global transform gives: the fonts module keeps one `love.Font` per face
(`fonts.Face`: one of the program's fonts by its path, `fonts.Kind`, or the
bytes of a font asset, a `love.FileData`) and integer pixel size, and
forgets a face on request (`fonts.forget`). Axis-aligned
text is drawn one glyph texel per screen pixel at a whole-pixel position;
rotated text keeps its transform and scales the glyphs inside it. A text,
and a text input through it, changes its face with `set_font`;
`Text:measure(text)` gives the width of any text as drawn, in model
units: measured in the font rasterized for the text's size on screen,
since its hinted advances are whole pixels and the reference font scaled
down misses them by a glyph over a line, which is where the text input
places its caret.

`TextInput` is one line of text over a `TextBuffer`: the caret is drawn at
the width of the text before it (the bullets of a masked field), the
selection as a rectangle under the text in `TEXT_INPUT_SELECTION_COLOR`,
and the content scrolls inside the field's clip only as far as keeping
the caret in view needs. A press with the left button focuses the field
and puts the caret at the nearest glyph boundary (Shift extends the
selection to it); the press is captured, so a drag selects wherever the
pointer goes; a second press within `MULTI_CLICK_INTERVAL` selects the
word, a third everything. Focus by Tab selects everything, so Tab, type,
Tab replaces a field. Typing replaces the selection; copy and cut are
refused by a masked field, whose Ctrl+Backspace clears it; a paste comes
flattened from the manager. The pointer over a field shows the I-beam
cursor where the system offers one (`love.mouse.isCursorSupported`: not
under the offscreen driver). `NumberInput` is a text input whose buffer
filter accepts the empty text, a lone minus and what `tonumber` parses,
asked with the whole text an edit would produce, so an insertion in the
middle and a paste are checked as a keystroke at the end is. A read-only
input takes no focus and so has no caret, as before.

`SelectionBox` (`ui/selection-box.lua`) is one option of a closed set
(`SelectionOption[]`: a `key` the program reads and writes, a `title` the
user sees) shown as a field: the selected option's title at the left,
clipped before the arrow, in the input font as a text input's content,
and the arrow at the right edge, a `Triangle` pointing down
(`controls/triangle.lua`, the primitive filling its box with
`love.graphics.polygon`, drawn as the caret is a `Rectangle`, since the
display font has no such glyph), over a background in the button colors
a text input uses. A
press, or Return or Space while focused, opens the list
(`SelectionBoxList`, `ui/selection-box-list.lua`): a tree parented to the
form screen's control as its last child, so it draws over the screen and
is hit first, and anchored to the box, so it dies with the box or with
the screen; a backdrop over the whole screen takes every press outside
the list, which closes it and reaches nothing under it, and the rows
(`SelectionBoxRow`, one per option, as tall as the box, in a scroll view
showing at most `SELECTION_BOX_MAX_ROWS` of them with the selected one in
view, under the box, or above it when there is no room below) highlight
under the pointer or with Up and Down, the wheel scrolls them and reaches
nothing under the list, and a press on one, or Return, picks it: the box's selection changes, the list closes, `on_change` runs
when the key differs. A press is only recorded by the pointer dispatch
and acted on from the list's own `Button` (the button manager runs after
the pointer dispatch, so a list gone at the press would leave the manager
pressing what is under it). Up and Down on a closed focused
box step the selection directly. The list closes too when the focus
moves on (Tab), the screen hides, the box becomes read-only, the options
are set (`set_options`, which keeps the selected key when it is still
among them), the selection is set (`set_selected`) or the window
resizes; `set_selected` and `set_options` never run `on_change`. Escape stays the back key. A scenario finds the
box by its shown title and a row of the open list by its title
(`driver:click("SelectionBox", "Player")`,
`driver:click("SelectionBoxRow", "Game master")`).

`Image` draws a `love.Image` the images module made with its mipmap chain,
filtered linearly within and between the levels, so a downscaled image (a
token avatar, a zoomed-out page) samples the level of its on-screen size
instead of skipping texels; the module keeps one image per file path, which
the asset manager forgets when it writes the file again. An axis-aligned
image is drawn at a whole-pixel position and, when its scale is within half
a pixel of one texel per screen pixel, exactly at that; a rotated image
keeps its transform. `Video` draws a `love.Video` the same way; both share
the placement through `DrawableControl`.

## Screen Management

`ScreenManager` shows one screen at a time (`show(screen)`); screens are
full-screen UI containers: ConnectingScreen, LoginScreen, UserMenuScreen,
OptionsMenuScreen, GameScreen, NewTokenScreen, AssetsWorkspaceScreen,
WaitingScreen, and ScreenSaver for a server with a window.

## The Page

`Page` (`game/page/page.lua`) is the view of a page: a `ClippingRectangle`
over the game screen's map area, with the map image as the camera (its
position, origin and scale are the view) and, under the image, a `Control`
scaled to page meters that the tokens and the selection live in. The wheel
zooms about the pointer, the view-drag button pans, `fit`, `fit_page`,
`fit_token` and `center_on` place the view, and the game screen resizes it
with the window. Every one of these ends in the same constraint: the scale
stays between the zoom-out limit, where the whole page fits the view within
`PADDING` (exactly what `fit_page` sets), and the zoom-in limit,
`PAGE_MAX_UNITS_PER_METER` model units per page meter (a centimeter of the
page is two units, about a screen pixel or two; a page so small that its
fit exceeds the limit has a range of one scale), and the map keeps at least
`PAGE_MIN_VISIBLE` units in view along each axis, a strip along an edge or
a square at a corner. The wheel clamps its target scale first, so a zoom at
the limit still zooms about the pointer; a fit that would exceed the zoom-in
limit (a 1 m token) ends at the limit with the rectangle centered; a drag
that hits the limit leaves the map at it until the pointer comes back; a
page at the zoom-out limit is fitted again when the view's size changes, so
a fully zoomed-out map stays whole through a window resize.
All of this is measured against the page's fit area (`get_fit_size`),
the view's size with the side bar shown, which `set_size` sets: a hidden
side bar only extends the view over its strip (`set_extension`), where
the map is seen as it is, so the fits, the zoom limits and the pan limit
are the same with the side bar and without, and toggling it neither
scales nor moves the map.

Beyond the map's edges the view shows `PageSurroundings`
(`game/page/page-surroundings.lua`), the page's first child: one draw of the
map image over the whole view, with a quad whose viewport is the view in map
texels (a viewport beyond the texture samples the edge texels, the `clamp`
wrap every image has), under a shader that blurs each fragment by its
distance beyond the edge: sigma is `PAGE_SURROUNDINGS_BLUR_GROWTH` times the
distance, capped at `PAGE_SURROUNDINGS_BLUR_LIMIT` page meters, so the belt
where the blur grows is fixed in the world and widens on screen as the view
zooms in; a 5x5
binomial kernel on taps half a sigma apart, sampled from the mip level whose
texel is about half a sigma, never below the level an ordinary draw would
use at this zoom. The level is explicit (`textureLod`, so the shader is
`glsl3`): the taps' offsets change with the distance, so the level the
sampler derives from screen derivatives would differ between the taps and
jump where the cap is reached, a visible line. Everything beyond the edge
is scaled by `PAGE_SURROUNDINGS_BLUR_BRIGHTNESS` (above 1 brighter, below 1
dimmer), stepping over one screen pixel at the edge (`base_lod` gives the
texels per pixel), so the end of the map shows as the step in brightness
while what lies beyond it stays soft. Under the map the taps collapse to
the plain sample, and the map image, drawn after it, covers it.
A GPU without `glsl3` gets no surroundings: the clear color, as before.
## Tokens

A token (`game/token/token.lua`) is a `Model` over its `TokenData` and a
control on the page: the avatar (`Avatar`, `game/token/avatar.lua`: the
image covering a circular clip of the token's diameter), the label, the
selection ring. Its **id** is its key in `GameData.tokens`, what the
pages' token lists and the grants (`write:tokens/<id>`) name; it is not a
field of the data and not the display name (`name`). The token panel
(`TokenPanel`) edits the selection: an Id field above the properties, then
one field per property of `token_properties` the selected tokens have (a
`string`, a `number`, an `image` with its button to the assets workspace
and, when the selected tokens agree on a file the store holds, the image
itself above the path: the avatar in its circle as on the page, the
same `Avatar` control, another image fitted into a square, both of
`TOKEN_PANEL_IMAGE_PREVIEW_SIZE`), in a scroll view above the one row of buttons: Cancel at the
left edge with New beside it, Apply at the right edge, Delete centered
between New and Apply, each where it always sits. New is
there with or without a selection, read-only without `write` on the
tokens kind, and opens the new token screen. The Id field is editable with
exactly one writable token selected; with several it is read-only and
multivalue (the yellowish disabled field), since an id is one token's.
Apply, or Enter in a field, applies the id first, then the properties:
`token_id.check` (`game/token/token-id.lua`) refuses an empty id, one
starting with `@` (a grant on it would read as a selector) or one another
token has, each with a notification carrying the reason; an accepted id
goes through `Token:set_id`, which renames the key in the data
(`token_id.rename`: the entry, every page's token list, the grants on the
token in the groups' and the players' permissions) and in the session's
permission set (`PermissionSet:rename_key`), so the token stays as writable
as it was.
The panel is the game's side bar, beside the page (`GAME_SIDE_PANEL_SHARE`
of the width): the quick access panel's Tokens entry toggles it
(`GameScreen:toggle_panel`), shown in the active colors (`BUTTON_ACTIVE_*`,
blueish) while the panel is up. Hidden, the page's view and the quick
access panel extend over its strip in the same frame, the map neither
scaled nor moved (`Page:set_extension`), and the panel's inputs, disabled
with it, are skipped by Tab.

A change is applied to the client's copy first and then sent to the server
(`Session:update_token`): the page sends one `UpdateTokenRp` request per
token a drag moved when the drag ends, with the token's id and its
position; the panel sends one per token Apply changed, with the rename
(old and new id) and the changed properties; the workspace's Use the same
for an image property. The server (`UpdateTokenRp:send_response`) refuses
a session not in a game, an unknown id, a session without `write` on the
token, a change outside `position` and the `string`, `number` and `image`
properties or with a value of the wrong type (an `array` property, such as
`owners`, is not changeable over the wire), and a new id `token_id.check`
refuses, each with a reason; otherwise it renames the key in the data and
in the `PermissionSet` of every live session of the game, sets the
changed fields, saves the game and pushes the change (`TokenChangedRp`,
with the token as the server now holds it) to every other session in the
game that may `read` the token. The response carries the server's entry
when the session may read it: on a refusal the client notifies the reason
and restores the token from it (the id renamed back, the position and the
properties set), and on a success it applies the entry too, so the
client's copy converges on the server's at every answer: two clients
changing one token at once both end on the server's last write (a token
the user is dragging again when the answer lands sits at the server's
position for a frame). A
client receiving a push applies what differs (the rename first; an image
property, or `avatar` for a player who may not read the properties, whose
file the store lacks is downloaded before it is set), to its data and to
the token on the shown page (`Page:try_find_token`), and rebuilds the
token panel when the token is selected; a token it does not hold (one it may not read) is logged and
ignored. A client that left the game to the menu still holds the data and
receives the pushes, applied to the data only.

A token is created from the token panel's New button,
read-only without `write` on the tokens kind: `NewTokenScreen`
(`screens/new-token-screen.lua`), a menu screen over the game with the
fields Id, Name and Avatar (a path in the game's store, typed or chosen
with Browse..., which opens the assets workspace with an `AssetPick` and
fills the field on the way back) and the buttons Browse..., Create and
Back; Enter in any field creates too. Create checks the id
(`token_id.check`), the name and the avatar, each refusal a notification
that keeps the screen, and sends `CreateTokenRp` (`Session:create_token`)
with the shown page and an entry of a 1 m diameter at the view's center
(`Page:get_view_center`); the screen closes once the server created the
token, and leaving the game or logging out closes it too. The server (`CreateTokenRp:send_response`)
refuses a session not in a game or without `write` on the whole kind, an
id `token_id.check` refuses, an unknown page, an entry lacking `name`,
`diameter`, `avatar` or `position`, a key a change may not set
(`token_id.find_unchangeable`, the one rule of both procedures; `owners`
among the refused: a created token belongs to the game, so
nobody's `@owned` grant covers it and who may move it is a matter of
grants alone) or an avatar the game's store has no file for; otherwise it
copies the accepted fields into the data, appends the id to the page's
token list, saves and pushes `TokenCreatedRp` (the id, the page, the
entry) to every other session of the game that may read the token. The
creator's answer and the push take one path, `Session:apply_token_created`:
an avatar the store lacks is downloaded first, the entry goes into the
data and the page's list, and the shown page builds the control
(`Page:add_token`). A token is deleted with the token panel's Delete
button, shown between Cancel and Apply for a writable selection of at
least one token, one `DeleteTokenRp` per selected token: the server refuses a session not in a game, an unknown id or a
session without `write` on the token; otherwise it decides who may read
the token before removing it, removes it (`token_id.remove`: the entry,
every page's list, the grants naming it in the groups' and the players'
permissions) and the grants on it from every live session's set
(`PermissionSet:remove_key`), saves and pushes `TokenDeletedRp` to those
sessions. The client's path, `Session:apply_token_deleted`, drops the
control from the shown page (`Page:remove_token`: out of the drag in
progress and the selection, then destroyed, the token panel rebuilt), the
entry from the data and the grants from its own set. A creation and a
deletion are applied when the server answers, so a refusal has nothing to
restore; a change stays applied first, so a drag never snaps back while
the answer is on its way. What is left for the next slice: pages,
players, groups and token properties are not synchronized, and a property
cannot be deleted (the wire carries no `nil`; an apply while a `number`
field that is not left multivalue holds no number is refused as a whole,
before the rename, with the notification `<Title> needs a number`,
nothing applied or sent and the fields keeping their text).

## Entries

An *entry* is one value of a collection of `GameData` by its key: a page
(`pages[id]`), a group (`groups[id]`), a player (`players[login]`), a
token property (`token_properties[key]`) or the `game` entry (the shown
page), a singleton reached under the id `entries.GAME_ID`. Tokens keep
their own procedures. One module, `entries` (`game/entry/entries.lua`),
holds the rules on both sides: the fields of each kind (`entries.FIELDS`:
a page's `name`, `width`, `pixel_per_meter` and `image`; a group's
`title` and `permissions`; a player's `group` and `permissions`; a token
property's `title` and `type`; the game's `page`), which kinds can be
created, renamed and deleted (pages, groups and token properties; a
player joins by entering the game, the game entry is one), and the checks
(`check_id`, `check_rename`, `check_changes`, `check_new`,
`check_delete`), each answering a reason for the user: a value of the
wrong type, a grant `permissions.parse` refuses, a group or a page that
does not exist, a page image that is not a file of the store (the server
asks with the store), the shown page or a page still listing tokens
deleted, a group a player is in, a token property a token holds (its
`type` cannot change then either), and the properties every token has
(`name`, `diameter`, `avatar`, `position`: `entries.PROTECTED_PROPERTIES`)
renamed, deleted or retyped. A rename (`entries.rename`) follows the key
through what names it: `game.page` for a page, the players' `group` for a
group, the key in every token for a property, and the grants on
`kind/id` in the groups' and the players' permissions; a removal
(`entries.remove`) drops the grants too.

The procedures mirror the token ones: `UpdateEntryRp` (the kind, the id,
an optional new id, the changed fields), `CreateEntryRp` (the kind, the
id, the entry) and `DeleteEntryRp` (the kind, the id) from the client;
the server refuses a session not in a game, an unknown kind or id, a
session without `write` on `kind/id` (`write` on the whole kind for a
creation) and whatever the checks refuse, each with a reason and, for a
change, the entry when the session may read it; otherwise it applies the
request, rebuilds the permission set of every live session of the game
from the data (`Game:refresh_permissions`, since a group's or a player's
grants may have changed, or a key the grants name), saves and pushes
`EntryChangedRp`, `EntryCreatedRp` or `EntryDeletedRp` to every other
session that may `read` the entry, and `GrantsChangedRp` (the session's
grants, as the game data response carries them) to every session whose
grants changed, the requester included. Nothing is applied on the client
before the server answers: the response's entry and the pushes take one
path (`Session:apply_entry`, `apply_entry_created`,
`apply_entry_deleted`), which renames the key in the client's data and
its permission set, sets the fields, and tells the game screen
(`GameScreen:on_entries_change(kind, id)`, so the side panels rebuild;
and first `GameScreen:show_page(id)` when the shown page changed or its
image, width or scale did, after the assets it needs are downloaded as
at the join; a player whose client does not hold the newly shown page is
sent back to the menu with a notification, an open assets workspace
closed first). `GrantsChangedRp` rebuilds the
client's set (`Session:apply_grants`) and re-gates the game screen
(`GameScreen:on_grants_change`: every side panel, the token panel's
New button among what they gate); the data the client holds is not re-filtered (a
`read` grant given mid-game shows its entries at the next join).

### The side panels

The game screen's side bar holds one panel at a time, each toggled by a
quick access entry (`GameScreen:add_side_panel(panel, caption)`;
`SidePanel`, `game/side-panel.lua`, is the base: `on_entries_change`,
`on_grants_change`, `on_selection_change`): the token panel (`Tokens`),
then `Game`, `Pages`, `Groups`, `Permissions` and `Token Properties`.
`GamePanel` (`game/panels/game-panel.lua`) names the shown page and
offers a button per page the client holds, the shown one in the active
color; a click sends the change (`update_entry` on the game entry), and
the page switches when the server answers; the buttons are read-only
without `write` on `game`. The other four are `EntriesPanel`
(`game/panels/entries-panel.lua`) over a kind: a list of the ids in a
scroll view (the selected one active), an Id field, one field per
`EntryField` (a text input, a number input, a read-only path with
`Browse...` into the assets workspace for an image, the grants separated
by spaces, a selection box for an `enum` such as a token property's
`type` and for a player's `group`, over the game's groups by their titles;
a value outside the options is shown as an option of its own, so the
field shows the truth and Apply sends nothing for it untouched), and the
buttons `New` and `Delete` above `Cancel` and
`Apply`. `New` empties the fields for a creation; `Apply` sends only the
fields that differ (with the rename when the Id field changed) after the
module's checks, a refusal notified before anything is sent; `Delete`
sends the deletion; `Cancel` refills the fields from the data. Without
`write` on the selected entry the fields are read-only and Apply and
Delete absent; without `write` on the kind there is no New. The players
panel (`Permissions`) edits each player's group and own grants only.

## Asset Management

Every game has an asset store of its own: `AssetStore`
(`data/asset-store.lua`) is one store bound to its root, `s/games/<id>`
on the server (the game's, `Game:get_store`) and `c/games/<id>` on the
client (the joined game's, set by the game data response and reached
through `AssetManager:get_store`). It lists the whole store (`list`,
parents before their content), resolves an asset's real path for LÖVE
(`get_path`) and changes the store: a mounted file (`mount_file`), a
folder (`make_folder`), a move (`move`, a file or a folder with
everything under it) and a removal (`remove`), each validated and refused
with a reason for the user. `Asset` wraps LÖVE's filesystem: one real
path of the save directory, read, written, moved, removed, and the path
helpers (`check_path`, `get_name`, `get_parent`, `join`, `is_under`).
`AssetManager` tracks the procedures per session (on the client, the
procedures used are its own session's), downloads missing assets from the
server on demand and uploads new ones. The procedures are
DownloadAssetRp, DownloadMissingAssetsRp,
UploadAssetRp, ListAssetsRp, CreateAssetFolderRp, RenameAssetRp and
DeleteAssetRp; the listing needs `read` on `assets`, every change `write`
on `assets`. A rename keeps the game pointing at the renamed assets (the
pages' images, the tokens' image properties: `asset_usage`), a delete is
refused while the game uses the asset or something under the folder. The
client mirrors a rename and a delete on its own copies.

The assets workspace (`game/assets/workspace/`) is the store as a file
manager, opened from the game's quick access panel (its Assets entry), in
three columns: `AssetList` shows one folder, folders first, scrolled with
the wheel (the rows out of view disabled, so Tab skips them), a whole-row
button (`AssetListRow`) per entry; `AssetDetails`
holds the preview (the drop target, see [Media](#media)), the name field
the actions use, the type and the action buttons; `AssetUsageList` names
what uses the selected
entry (`asset_usage.find`: the pages by their image, the tokens by their
image properties, a folder by everything under it), a text button per use,
dimmed when the page or the token is not on the shown page, and a click
closes the workspace and fits the game's view to it, as the preview fits an
image (`Page:fit_page`, `Page:fit_token`), a token selected on its own
(`Selection:select_tokens`). The way there and back from a token: an
`image` property in the token panel shows its path read-only with a
"Browse..." button ("Show in assets..." for a read-only selection), which
opens the workspace at that asset (`AssetPick`), and the workspace then
offers Use on an image file, which sets the property on the selected
tokens and returns to the game; `AssetsWorkspaceScreen`
keeps the state (the listing, the
shown folder, the selection, the dropped file), asks the server and gates
the buttons: a selected folder can be opened (a second click too) and
deleted, a selected entry renamed to a free name, a free name made a folder,
a dropped file uploaded under the typed name into the shown folder (over a
file, never over a folder). A read-only button is dimmed and skipped by the
pointer and by Tab. What the server refuses is notified with its reason; the
listing is asked again after every change.

## Media

The media module (`utils/media.lua`) types a file by trying LÖVE's
constructors on its bytes in a fixed order, the first to succeed deciding
(`media.get_type_and_medium(data, path)`, the dynamic dispatch pattern of
[conventions.md](conventions.md)): video, image, font, audio. The order
matters: LÖVE's audio decoders accept nearly any bytes (a TTF font decodes
as mp3), so audio is tried last; and LÖVE opens a video only from a file,
never from its bytes, so a video is recognized by its container instead:
the `ogg` module (`utils/ogg.lua`, pure Lua) finds the Theora
identification header among the Ogg pages (`ogg.find_theora`) and reads
the duration LÖVE does not expose from the last page's granule position
(`ogg.theora_duration`, `media.video_duration`). The `path` is where LÖVE
reads the file, for a file of the store; a dropped file has none, so it is
typed as a video but gets no medium until it is uploaded. A video is opened
with its audio track when it has one, without when it has none.

The preview area (`game/assets/preview-area/`) shows one component per
type, built under the workspace's form (`PreviewArea:get_form_screen`) with
the medium and the file's data, destroyed by `reset` or with the area:
an image fitted into the area (`PreviewImageArea`); a video (`Video`,
fitted above the player, `PreviewVideoArea`) or an audio file (the note
symbol, `PreviewAudioArea`) with a `MediaPlayer` across the bottom; a font
(`PreviewFontArea`) with a text field whose face is the file's bytes,
holding a pangram (`FONT_PREVIEW_TEXT`) the player can edit, and the
same text wrapped above it at a larger scale. Text and Lua files have no
preview yet.

`MediaPlayer` (`ui/media-player.lua`) drives a `Playback`, the common
face of a `love.Source` (`SourcePlayback`) and a `love.Video`
(`VideoPlayback`, with the duration the Ogg pages gave): a Play/Pause
button, a Stop button, the time as `m:ss / m:ss` (the position alone when
the duration is unknown), and a `SeekBar` (`ui/seek-bar.lua`) whose
indicator is the scroll view's, at the fraction played; a press or a drag
on the bar seeks, the pointer held by capture meanwhile. The player follows
the playback every frame (`app.update_event`): a playback that ends on its
own shows Play again, and Play at the end starts over. The player's
`release` stops the playback, so a preview that is replaced or dies with
the workspace falls silent; a death the collector found leaves the LÖVE
objects alone, as [lifetimes.md](lifetimes.md) requires.

## Permissions

Groups, grants and their enforcement are data in the game state and one
module (`permissions`) plus one class (`PermissionSet`) used on both sides:
the server filters the game data it sends by `read`, pushes a token change
only to the sessions that read the token, applies one only with `write` on
it, creates a token only with `write` on the whole kind and deletes one
only with `write` on it, lists the assets only with `read:assets`, refuses uploads, folders,
renames and deletes without `write:assets`; the client gates editing and
dragging of tokens, the upload button and the workspace's actions. See [permissions.md](permissions.md).

## Data Persistence

The server persists the accounts and every game as human-readable Lua
tables: `table.to_string()` serializes (a string on one line, its quotes
and backslashes escaped), `table.from_string()` deserializes; the server
reads them at startup and writes a file when it changes (an account
created, a game created, a player joined, a token changed, created or
deleted, an asset renamed). A game's state holds its name,
the pages, tokens and token properties, the players (their group and
grants; the account holds the name and the auth) and the permission
groups (`GameData` in `game/game-data-rp.lua`). The source tree's
`server/template/` (what a new game starts from) and the scenario
fixtures under `scenarios/fixtures/` (what a scenario's server root gets)
mirror the root's layout; they are data, not source code.

## Backstack Navigation

`BackstackManager` keeps a stack of entries for back navigation (like a
browser history). `push(cb)` returns the entry, which the caller anchors to
what it is for (a screen, the logged-in token); an entry leaves the stack
when it dies. On the back key the top entry is destroyed and its callback
invoked. The session pushes the entries of the screens it opens (the sign-up,
the Games menu, the games to join, the new game, the games to delete, the
question about one, the game, the new token screen, the assets workspace)
once, when it opens them, so a screen shown again (the game after the
workspace) gets no second entry; joining a game destroys the games to
join, the new game screen and the Games menu with their entries, so none
stays under the game's.

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
- `love.run` is the project's `MainLoop` (`app/main-loop.lua`): the events,
  `app.service_event` (the console's turn), the update with its delta (the
  real one, or a fixed one without sleep headless, plus a skip), the draw of
  the root and of `app.overlay`; the app's clock is the sum of the deltas
- The client uses love.graphics, love.window, love.keyboard, love.mouse and
  love.touch; both sides use love.thread, love.channel and the bundled
  `enet` module for networking
- The server can run headless (no graphics) or with a minimal UI

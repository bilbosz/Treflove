# TODO

High-level milestones. Each one will later be split into smaller, actionable chunks.

## Milestones from the README

### 1. Game master scripting

The core design goal: let the game master define game rules in Lua and modify
game state (tokens, objects, maps, sound) live during play.

- Decide how GM scripts are loaded, sandboxed, and hot-reloaded on the server
- Expose a scripting API over game data and sessions

### 2. Game state synchronization

The game data procedure sends the full state on every join, so a late
joiner gets the whole game as the server holds it. Tokens travel:
`UpdateTokenRp` carries a drag, the panel's Apply and an image chosen in
the workspace, `CreateTokenRp` a token made from the game's New Token
entry and `DeleteTokenRp` one deleted from the panel, to the server, which
checks `write`, saves and pushes `TokenChangedRp`, `TokenCreatedRp` or
`TokenDeletedRp` to every other session of the game that reads the token
([docs/architecture.md](docs/architecture.md), "Tokens"); the client
converges on the server's entry at every answer. Still missing:

- Pages, groups, players, token properties and the shown page travel
  as entries (`UpdateEntryRp`, `CreateEntryRp`, `DeleteEntryRp` and
  their pushes, [docs/architecture.md](docs/architecture.md),
  "Entries"), edited from the game's side panels. Still by hand: a
  token's `owners` and a player removed from a game; a page's token list
  moves with the token procedures only, so a token cannot change its
  page yet
- A `read` grant given mid-game (`GrantsChangedRp` carries the grants)
  does not re-send the entries it now covers: they arrive at the next
  join
- A page image changed by another client is downloaded before the shown
  page is rebuilt; an image of a page that is not shown is not
- A group's or a player's grants are edited in one single-line field,
  separated by spaces, so a long list shows its end only; a list of
  fields, one grant each, would read better
- Deleting a property (the wire carries no `nil`; a property of a token
  can only be set, and a `number` field holding no number refuses the
  apply), and giving a token a property it lacks
- Mid-game asset additions beyond the avatar a push names (a page image
  changed by another client is not downloaded)
- A deletion asks no confirmation; a token deleted by another client
  while its panel is open loses the edits typed into it
- A creator with `write` but no `read` on the tokens gets no entry back
  (the response carries it only when the session reads it, as a change's
  does), so the token appears nowhere on their client
- A grant given in the save file while a player is in the game reaches
  their session at the next join; one given from the Permissions panel is
  pushed (`GrantsChangedRp`)

### 3. Game objects other than tokens

Only tokens exist today.

- Generalize the object model (e.g. areas, cards, dice, drawings, labels)
- Shared object lifecycle: creation, ownership, persistence, panel UI

### 4. Prefabs

Reusable object templates the GM can instantiate during play.

### 5. Media other than images

The media module types videos, images, fonts and audio, and the assets
workspace previews them (a player for a video or an audio file, a text
field for a font); the game data and the game itself handle images only.

- Audio playback in the game (background music, sound effects)
- Ability to change board and background music at will during a game
- A dropped video is typed by its Ogg container but not played before it
  is uploaded: LÖVE opens a video from a file only, and a dropped file is
  outside its file system; a scratch copy in the save directory would let
  it play
- Text and Lua previews (the game master's scripts): LÖVE's audio decoders
  accept nearly any bytes, so a text type must be detected before audio
- Typing a file copies its bytes into a Lua string to look for the Theora
  header, a video twice (its duration); a prefix and a suffix through
  `love.data.newDataView` would do

### 6. Clipping of controls outside the clipping rectangle

The clipping mask clips drawing via stencil, but children outside the
rectangle still participate in layout and hit testing and are fully
processed.

- Cull controls that fall entirely outside the clip rect (draw + input)

### 6b. Permissions, the next consumers

The permission model ([docs/permissions.md](docs/permissions.md)) resolves
`read`, `write` and `view` grants; today the server enforces `read` (the
game data it sends and the token changes, creations and deletions it
pushes), `write:tokens` (a token change or deletion on the token,
`UpdateTokenRp`, `DeleteTokenRp`; a creation on the whole kind,
`CreateTokenRp`) and `write:assets` (uploads), the client gates token
editing, dragging, creation and deletion.

- A vision system is the consumer of `view`: a player sees what the tokens
  they own and the tokens they have `view` on see (fog of war); until then
  the grant is resolved and sent but changes nothing on screen
- The entry procedures check `write` on the changed entry as
  `UpdateTokenRp` does for a token; the client-side gating is a
  convenience, not the guard
- Groups and per-player grants are edited from the game's side panels;
  the group a joining account lands in (`player`) is named in the code,
  so a game whose master deleted it (refused while a player is in it)
  gives a newcomer no grants
- A token's id renamed in the token panel travels with `UpdateTokenRp`:
  the server renames the key in the data and in the set of every live
  session of the game, and the push renames it on the other clients; the
  `owners` of a token are still edited in the save file only (an `array`
  property is not changeable over the wire)

## Milestones from code review

### 7. Account and game management

An account is created from the login screen and kept by the server in
`s/accounts.lua`; a game is created from the menu's New Game and any
account may join any game from its Join Game ([docs/architecture.md](docs/architecture.md),
"Accounts and Games"). What is still done by hand in the files:

- Changing a password, a display name, deleting an account
- Removing a player from a game, and private games, by invitation or
  password, once a game should not be open to every account (a first join
  lands every account in the group `player`; the Permissions panel moves
  it to another)
- Deleting or renaming a game; a games list that scrolls once it outgrows
  the window (the menu screen lays its entries out once, top to bottom)
- Moving a token to another page: pages are made, changed and deleted
  from the Pages panel, but a token stays on the page it was created on
- A root from before the accounts (an `s/save.lua` without an
  `s/accounts.lua`) is emptied and seeded, as every start emptied it before;
  a migration into `s/games/<id>/` would keep such a root's state

### 8. Authentication hardening

The salt generator is seeded with fixed constants, so the "salt" is a static
pepper shared by all users.

- Per-user random salts stored with the account, and a proper KDF for hashing
- The login procedure scans all accounts per login attempt to find a user by
  its client auth; index by auth instead

### 9. Connection resilience

- Client-side reconnect after a dropped connection (beyond the initial
  connecting screen), with session state recovery
- Timeouts and user-visible errors for failed RPCs instead of silent stalls
- Graceful server-side session teardown on abrupt disconnects
- A request handler that raises (a malformed body past the checks) still
  kills the receiver; a `pcall` around the handler that answers a refusal
  would keep the loop alive

### 10. Save robustness

- Atomic writes for the save file (write to a temp file, then rename) so a
  crash mid-save cannot corrupt the state
- Autosave cadence instead of relying on explicit saves
- Version the save format to allow future migrations

### 11. Broader test coverage

The suite covers utilities, events, networking basics, the session and the
object lifetimes. Missing areas:

- Control hierarchy: transforms, AABB computation, event propagation, clipping
- Serialization round-trips of real game data (pages, tokens, players)
- RPC classes beyond Connection (login, asset transfer, game data)

### 12. A bug the strict typing pass found, left as it is

Typing the code made a runtime fault visible; it is a behavior decision,
so the annotations say what happens today and the code is unchanged.

- `networking/detail/connection-dispatcher.lua`: when server-in pushes
  `false` (it could not bind), the dispatcher logs `"... with port " ..
  in_port` and raises on the boolean, which kills the dispatcher until the
  connector restarts it; `tostring(in_port)` is the one-line fix

### 13. Texture atlases, once measured

Every image is its own texture, with its mipmaps; LÖVE batches consecutive
draws of one texture, and the per-path image cache makes the tokens of one
avatar share theirs. An atlas (many images packed into one texture, drawn as
quads from a sprite batch) pays off only once draw calls are the bottleneck
(`love.graphics.getStats().drawcalls` in the thousands per frame), and each
token is drawn inside its own stencil mask today, which ends a batch anyway.

- Measure first; build an atlas only for a measured frame budget
- Avatars arrive as uploads at runtime, so the atlas is packed at runtime
  (a canvas), and each entry is padded by the depth of the mipmap chain it
  is drawn with, or the chain bleeds the neighbours in
- A page image larger than the texture size limit
  (`love.graphics.getSystemLimits().texturesize`) cannot be loaded at all;
  split such an image into tiles on the server or at load

### 14. Scenarios and the console, next steps

The scenarios run headless on the offscreen SDL driver and the console
port drives the live program ([docs/scenarios-and-console.md](docs/scenarios-and-console.md)).

- A CI job for the scenarios: GitHub's runners have no GPU, and the
  offscreen driver needs a working EGL; try `xvfb-run` with llvmpipe or a
  software EGL on the runner before adding the job
- An in-process tier: both apps in one Lua state over crossed channels, as
  the lifetimes suite does, for scenarios in milliseconds; needs the apps to
  stop registering the LÖVE callbacks themselves, and lives with the global
  `app` swap
- Record and replay: the input callbacks and the incoming wire of a windowed
  session to a file, replayed headless against the seeded random generator
  and the fixture, so a bug reproduced by hand becomes a scenario
- The suite's own click helpers (the lifetimes suite, the game client
  harness) could use the scenario driver's `find` and `click`
- Multi-client scenarios drive peers from a lead client (`move-token` is
  milestone 2's first acceptance scenario); a conductor outside every
  client (a `luajit` script over the console ports) would serve symmetric
  cases
- A windowed client started from a shell on this machine presents at one
  frame per second (adaptive vsync under XWayland, `love.window.getVSync()`
  reports -1; `vblank_mode=0` gives hundreds), on `master` as well, so a
  windowed scenario takes a second per step; headless runs are unaffected.
  If the desktop shows the same, vsync off (`t.window.vsync = 0`) is the fix

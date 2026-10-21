# TODO

High-level milestones. Each one will later be split into smaller, actionable chunks.

## Milestones from the README

### 1. Game master scripting

The core design goal: let the game master define game rules in Lua and modify
game state (tokens, objects, maps, sound) live during play.

- Decide how GM scripts are loaded, sandboxed, and hot-reloaded on the server
- Expose a scripting API over game data and sessions

### 2. Game state synchronization

The game data procedure sends the full state once on login; changes made
afterwards do not propagate.

- Push incremental state updates from server to all connected clients
- Handle late joiners and mid-game asset additions

### 3. Game objects other than tokens

Only tokens exist today.

- Generalize the object model (e.g. areas, cards, dice, drawings, labels)
- Shared object lifecycle: creation, ownership, persistence, panel UI

### 4. Prefabs

Reusable object templates the GM can instantiate during play.

### 5. Media other than images

The media module already types sources, fonts and videos, but the asset
pipeline and the game data handle images only.

- Audio playback (background music, sound effects)
- Ability to change board and background music at will during a game

### 6. Clipping of controls outside the clipping rectangle

The clipping mask clips drawing via stencil, but children outside the
rectangle still participate in layout and hit testing and are fully
processed.

- Cull controls that fall entirely outside the clip rect (draw + input)

## Milestones from code review

### 7. Real login flow and user management

- Remove the hardcoded dev auto-login (`"adam"/"krause"`) from the session's
  constructor, or gate it behind a debug flag
- Users are currently added by hand-editing the server's save file, which
  also carries plaintext passwords in comments; add a way to create and
  manage accounts

### 8. Authentication hardening

The salt generator is seeded with fixed constants, so the "salt" is a static
pepper shared by all users.

- Per-user random salts stored with the account, and a proper KDF for hashing
- The login procedure scans all players per login attempt to find a user by
  its client auth; index by auth instead

### 9. Connection resilience

- Client-side reconnect after a dropped connection (beyond the initial
  connecting screen), with session state recovery
- Timeouts and user-visible errors for failed RPCs instead of silent stalls
- Graceful server-side session teardown on abrupt disconnects

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

### 12. Texture atlases, once measured

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

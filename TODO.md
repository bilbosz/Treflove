# TODO

High-level milestones. Each one will later be split into smaller, actionable chunks.

## Milestones from the README

### 1. Game master scripting

The core design goal: let the game master define game rules in Lua and modify
game state (tokens, objects, maps, sound) live during play.

- Decide how GM scripts are loaded, sandboxed, and hot-reloaded on the server
- Expose a scripting API over game data and sessions

### 2. Game state synchronization

[GameDataRp](game/game-data-rp.tlt) sends the full state once on login; changes
made afterwards do not propagate.

- Push incremental state updates from server to all connected clients
- Handle late joiners and mid-game asset additions

### 3. Game objects other than tokens

Only [Token](game/token/token.tlt) exists today.

- Generalize the object model (e.g. areas, cards, dice, drawings, labels)
- Shared object lifecycle: creation, ownership, persistence, panel UI

### 4. Prefabs

Reusable object templates the GM can instantiate during play.

### 5. Media other than images

[utils/media.tlt](utils/media.tlt) already types sources/fonts/videos, but the
asset pipeline and game data handle images only.

- Audio playback (background music, sound effects)
- Ability to change board and background music at will during a game

### 6. Clipping of controls outside the clipping rectangle

[ClippingMask](controls/clipping-mask.tlt) clips drawing via stencil, but
children outside the rectangle still participate in layout/hit testing and are
fully processed.

- Cull controls that fall entirely outside the clip rect (draw + input)

## Milestones from code review

### 7. Real login flow and user management

- Remove the hardcoded dev auto-login `"adam"/"krause"` at
  [game/session.tlt:74](game/session.tlt#L74) (or gate it behind a debug flag)
- Users are currently added by hand-editing [server/save.lua](server/save.lua),
  which also carries plaintext passwords in comments — add a way to create and
  manage accounts

### 8. Authentication hardening

`Utils.generate_salt` ([utils/utils.tlt:88](utils/utils.tlt#L88)) is seeded with
fixed constants, so the "salt" is a static pepper shared by all users.

- Per-user random salts stored with the account, and a proper KDF for hashing
- `_find_user_by_client_auth` in [login/login-rp.tlt](login/login-rp.tlt)
  scans all players per login attempt — index by auth instead

### 9. Connection resilience

- Client-side reconnect after a dropped connection (beyond the initial
  ConnectingScreen), with session state recovery
- Timeouts and user-visible errors for failed RPCs instead of silent stalls
- Graceful server-side session teardown on abrupt disconnects

### 10. Save robustness

- Atomic writes for `save.lua` (write to temp file, then rename) so a crash
  mid-save cannot corrupt the state
- Autosave cadence instead of relying on explicit saves
- Version the save format to allow future migrations

### 11. Broader test coverage

The suite in [tests/](tests/) covers utilities, events, and networking basics.
Missing areas:

- Control hierarchy: transforms, AABB computation, event propagation, clipping
- Serialization round-trips of real game data (pages, tokens, players)
- RPC classes beyond Connection (login, asset transfer, game data)
- Session lifecycle (login → screen transitions → logout/disconnect)

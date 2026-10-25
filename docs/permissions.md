# Permissions

Who may do what is data: the persisted game state names the groups, each
player belongs to one, and a player may carry grants of its own on top of
the group's. The server resolves a player's grants at login, filters what
it sends by them, and refuses what they do not cover; the client receives
the same grants with the game data and gates its UI by them. One module
and one class do all of it on both sides.

## The data

```lua
groups = {
    master = {
        title = "Game master",
        permissions = {"read", "write"}
    },
    player = {
        title = "Player",
        permissions = {"read"}
    }
},
players = {
    ["adam"] = {name = "Adam", auth = "...", group = "master"},
    ["piotr"] = {
        name = "Piotrek",
        auth = "...",
        group = "player",
        permissions = {"write:tokens/@owned", "view:tokens/Bilbosz"}
    }
}
```

- `groups` (`GroupData` by name): a title and a list of grants. The game
  master's group reads and writes everything; the player group reads
  everything.
- `players[login].group` is a key of `groups`; a group the table does not
  have contributes nothing (the server logs it).
- `players[login].permissions` (optional) adds grants to the group's. Piotr
  above is a player who may change the tokens they own and who shares the
  view of the token `Bilbosz`.

## A grant

A grant is one string, `<action>[:<kind>[/<key>]]`, read by
`permissions.parse` into a `Grant` (`action`, `kind`, `key`) and written
back by `permissions.format`.

| Part | Values | Absent means |
| --- | --- | --- |
| `action` | `permissions.Action`: `read` (the data reaches the player's client and is shown), `write` (the player may change it; the server accepts changes to it), `view` (the player shares the view of that token: sees the game through it as its owner does) | required |
| `kind` | `permissions.Kind`: a collection of `GameData` by its key (`pages`, `tokens`, `players`, `token_properties`, `groups`, `game`), or `assets` (the server's asset store) | every kind |
| `key` | an entry of the collection by its key (`tokens/Bilbosz`, `pages/Old Town`: everything after the first `/`), or the selector `@owned`: the entries whose `owners` array lists the player's login | every entry of the kind |

Parsing is strict: an action outside `permissions.Action`, a kind outside
`permissions.Kind` (so a typo grants nothing silently), an empty kind or
key, or a selector other than `@owned` raises. Nothing is implied between actions: `write`
does not grant `read`.

Examples: `read` (everything), `write:assets` (may upload),
`write:tokens/@owned` (may change the tokens one owns), `view:tokens/Bilbosz`.

## Resolving and asking

`permissions.resolve(data, login)` returns the group's grants followed by
the player's own, as strings. `PermissionSet(login, grants)` parses them
once; `set:allows(action, kind?, key?)` answers a question at any width:

- `allows(action)`: may the player do this to everything? Only a grant
  without a kind says yes.
- `allows(action, kind)`: to the whole collection? A grant without a kind,
  or for that kind without a key.
- `allows(action, kind, key)`: to one entry? Any of the above, the exact
  key, or `@owned` when `app.data[kind][key].owners` lists the login
  (ownership is read from `app.data` at the moment of the question, on
  both sides).

The session holds the set while the user is logged in
(`Session:get_permissions()`): the server builds it in the login callback
from `app.data`; the client receives the grant strings in the game data
response and builds its own (`Session:set_grants`). Both clear it at
logout.

## Where it is enforced

- **The game data** (`GameDataRp`): the server answers with
  `permissions.filter(app.data, set)`, a copy that keeps an entry of a
  collection only when the set may `read` it, keeps `game` only with
  `read` on `game`, prunes a page's token list to the kept tokens, and
  strips every player's `auth`. A collection the player may not read at
  all is an empty table. The response carries the grants, so the client
  asks the same questions the server did.
- **The asset store**: the listing (`ListAssetsRp`) answers only a session
  with `read` on `assets`, and tells it whether it may change the store
  (`writable`); an upload (`UploadAssetRp`), a folder
  (`CreateAssetFolderRp`), a rename (`RenameAssetRp`) and a delete
  (`DeleteAssetRp`) are done only with `write` on `assets`; otherwise the
  response says `success = false` and the client notifies the reason.
- **The client's UI**: the token panel is read-only (inputs read-only, no
  Apply, its "Show in assets..." button opens the workspace to look,
  without Use) when
  any selected token is not writable; dragging moves only the
  writable tokens of the selection; the assets workspace gates its name
  field and its actions by what the listing said (`writable`).

`view` is resolved and sent like the other actions; its consumer, a vision
system that shows a player what their tokens see, is future work
(see `TODO.md`). Until then it is the worked example of a grant on one
entry.

## Adding a permission check

Ask the session: `app.session:get_permissions():allows(permissions.Action.WRITE, "tokens", name)`
on the client, the connection's session on the server. A new kind is a new
member of `permissions.Kind`, a new action one of `permissions.Action`,
with its meaning written here.

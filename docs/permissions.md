# Permissions

Who may do what is data: a game's persisted state names the groups, each
of its players belongs to one, and a player may carry grants of its own on
top of the group's. The server resolves a player's grants when the session
joins the game, filters what it sends by them, and refuses what they do
not cover; the client receives the same grants with the game data and
gates its UI by them. One module and one class do all of it on both
sides. The accounts (`s/accounts.lua`: the display name and the auth by
login) are outside every game; a game's `players` names the accounts
that joined it, and games are open: an account that joins a game it is
not in yet is added to `players` in the group `player`.

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
    ["adam"] = {group = "master"},
    ["piotr"] = {
        group = "player",
        permissions = {"write:tokens/@owned", "view:tokens/Bilbosz"}
    }
}
```

- `groups` (`GroupData` by name): a title and a list of grants. The game
  master's group reads and writes everything; the player group reads
  everything. A new game starts with these two, its creator in `master`;
  the template's `player` group also writes the tokens its members own.
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
| `key` | an entry of the collection by its key (`tokens/Bilbosz`, the token's id; `pages/Old Town`; everything after the first `/`), or the selector `@owned`: the entries whose `owners` array lists the player's login | every entry of the kind |

Parsing is strict: an action outside `permissions.Action`, a kind outside
`permissions.Kind` (so a typo grants nothing silently), an empty kind or
key, or a selector other than `@owned` raises. Nothing is implied between actions: `write`
does not grant `read`.

Examples: `read` (everything), `write:assets` (may upload),
`write:tokens/@owned` (may change the tokens one owns), `view:tokens/Bilbosz`.

## Resolving and asking

`permissions.resolve(data, login)` returns the group's grants followed by
the player's own, as strings. `PermissionSet(login, grants, data)` parses
them once, over the `GameData` it reads ownership from (the game's on the
server, `app.data` on the client); `set:allows(action, kind?, key?)`
answers a question at any width:

- `allows(action)`: may the player do this to everything? Only a grant
  without a kind says yes.
- `allows(action, kind)`: to the whole collection? A grant without a kind,
  or for that kind without a key.
- `allows(action, kind, key)`: to one entry? Any of the above, the exact
  key, or `@owned` when `data[kind][key].owners` lists the login
  (ownership is read from the data at the moment of the question, on
  both sides).

The session holds the set while the user is in a game
(`Session:get_permissions()`): the server builds it when the session
selects the game (`Session:select_game`, from the game's data); the
client receives the grant strings in the game data response and builds
its own (`Session:set_grants`). Both clear it at logout; without a game,
every question is answered no.

## Where it is enforced

- **The game data** (`GameDataRp`): the server answers with
  `permissions.filter(data, set)` over the joined game's data, a copy that
  keeps an entry of a collection only when the set may `read` it, keeps
  `game` only with `read` on `game`, and prunes a page's token list to the
  kept tokens. A collection the player may not read at all is an empty
  table. The response carries the grants, so the client asks the same
  questions the server did. The auths never leave the accounts file.
- **The asset store**: the listing (`ListAssetsRp`) answers only a session
  with `read` on `assets`, and tells it whether it may change the store
  (`writable`); an upload (`UploadAssetRp`), a folder
  (`CreateAssetFolderRp`), a rename (`RenameAssetRp`) and a delete
  (`DeleteAssetRp`) are done only with `write` on `assets`; otherwise the
  response says `success = false` and the client notifies the reason.
- **A token change** (`UpdateTokenRp`): the server applies a change to a
  token, saves it and pushes it to the other sessions of the game only
  with `write` on the token (`write:tokens/<id>`, `write:tokens/@owned`
  with the ownership read from the data at the moment of the request, or
  wider); otherwise the response says `success = false` with the reason,
  the client notifies it and restores the token from the response. The
  push (`TokenChangedRp`) goes only to the sessions that may `read` the
  token, so a client never receives a token it was not sent.
- **A token created or deleted** (`CreateTokenRp`, `DeleteTokenRp`): a
  creation needs `write` on the whole kind (`write:tokens` or `write`), a
  deletion `write` on the token (`write:tokens/<id>`, `@owned` with the
  ownership read at the moment of the request, or wider). A created token
  has no `owners`, so nobody's `@owned` grant covers it: a group with
  `write:tokens`, or a `write:tokens/<id>` added to a player's permissions
  in the save, is who may move it. The push of a creation
  (`TokenCreatedRp`) goes to the sessions that may `read` the new token,
  the push of a deletion (`TokenDeletedRp`) to those that could read it
  before it went; the deletion removes the grants naming the token from
  the groups', the players' and every live session's set
  (`permissions.remove_key`, `PermissionSet:remove_key`).
- **A game deleted** (`DeleteGameRp`, from the Games menu's Delete
  Game): the user must be a player of the game with `write` on `game` in
  it (`write:game`, or `write` as the master group has); the server
  resolves the grants from the game's data at the moment of the request
  (`Game:allows`), whether or not the session is in the game, and the
  listing (`ListGamesRp`) tells each game's `deletable` the same way, so
  Delete Game offers only those. Every live session in the game leaves it
  and is told (`GameDeletedRp`), the deleter through the answer; the
  client drops the game's data and copies and, when it is in the game,
  goes back to the menu with the notification.
- **An entry changed, created or deleted** (`UpdateEntryRp`,
  `CreateEntryRp`, `DeleteEntryRp`: a page, a group, a player, a token
  property, the shown page; [architecture.md](architecture.md),
  "Entries"): a change or a deletion needs `write` on `kind/<id>` (the
  game entry under `game/game`, so `write:game` covers it), a creation
  `write` on the whole kind. The pushes go to the sessions that may
  `read` the entry. After every accepted request the server rebuilds the
  set of every live session of the game from the data
  (`Game:refresh_permissions`): a group's grants changed, a player moved
  to another group or given grants of their own, a key the grants name
  renamed or removed; and pushes `GrantsChangedRp` with the new grants to
  every session whose list changed, so a grant given from the
  Permissions panel works at once, without a new login
  (`Session:apply_grants`, then `GameScreen:on_grants_change`). The data
  the client holds is not sent again: an entry a new `read` grant covers
  arrives at the next join.
- **The client's UI**: the token panel is read-only (inputs read-only, no
  Apply, its "Show in assets..." button opens the workspace to look,
  without Use) when
  any selected token is not writable, and shows Delete for a non-empty
  writable selection only; the game's New Token entry is read-only without `write`
  on the tokens kind; dragging moves only the
  writable tokens of the selection; the assets workspace gates its name
  field and its actions by what the listing said (`writable`).
- **A token's id**: renaming it in the token panel renames the grants
  naming it, so `view:tokens/Bilbosz` follows `Bilbosz` renamed to `Bilbo`:
  `permissions.rename_key(grants, kind, key, new_key)` rewrites a list of
  grants, `token_id.rename` applies it to every group's and every player's
  permissions in the data, and `PermissionSet:rename_key` to a session's
  set: the client's own in `Token:set_id`, and on the server, when the
  rename is accepted, the set of every live session of the game
  (`Game:get_sessions`), so a grant naming the token keeps working for
  everyone in the game without a new login. An `@owned` grant needs
  nothing: ownership is read from the data under the new key.

The groups and the players' grants are edited from the game's `Groups`
and `Permissions` side panels; a grant typed there is checked by
`permissions.parse` on both sides before it is saved.

`view` is resolved and sent like the other actions; its consumer, a vision
system that shows a player what their tokens see, is future work
(see `TODO.md`). Until then it is the worked example of a grant on one
entry.

## Adding a permission check

Ask the session: `app.session:get_permissions():allows(permissions.Action.WRITE, "tokens", name)`
on the client, the connection's session on the server. A new kind is a new
member of `permissions.Kind`, a new action one of `permissions.Action`,
with its meaning written here.

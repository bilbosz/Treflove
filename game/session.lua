local Asset = require("data.asset")
local AssetStore = require("data.asset-store")
local AssetsWorkspaceScreen = require("game.assets.workspace.assets-workspace-screen")
local ConfirmDeleteGameScreen = require("screens.confirm-delete-game-screen")
local Consts = require("app.consts")
local CreateGameRp = require("game.create-game-rp")
local CreateEntryRp = require("game.entry.create-entry-rp")
local CreateTokenRp = require("game.create-token-rp")
local DeleteEntryRp = require("game.entry.delete-entry-rp")
local DeleteGameRp = require("game.delete-game-rp")
local DeleteGameScreen = require("screens.delete-game-screen")
local DeleteTokenRp = require("game.delete-token-rp")
local EntryChangedRp = require("game.entry.entry-changed-rp")
local EntryCreatedRp = require("game.entry.entry-created-rp")
local EntryDeletedRp = require("game.entry.entry-deleted-rp")
local GameDataRp = require("game.game-data-rp")
local GameDeletedRp = require("game.game-deleted-rp")
local GameScreen = require("game.game-screen")
local JoinGameScreen = require("screens.join-game-screen")
local GrantsChangedRp = require("game.entry.grants-changed-rp")
local ListGamesRp = require("game.list-games-rp")
local Login = require("login.login")
local LoginScreen = require("login.login-screen")
local GamesMenuScreen = require("screens.games-menu-screen")
local NewGameScreen = require("screens.new-game-screen")
local NewTokenScreen = require("screens.new-token-screen")
local PermissionSet = require("game.permission-set")
local SignUpScreen = require("login.sign-up-screen")
local TokenChangedRp = require("game.token-changed-rp")
local TokenCreatedRp = require("game.token-created-rp")
local TokenDeletedRp = require("game.token-deleted-rp")
local UpdateEntryRp = require("game.entry.update-entry-rp")
local UpdateTokenRp = require("game.update-token-rp")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")
local entries = require("game.entry.entries")
local lifetime = require("lifetime")
local permissions = require("game.permissions")
local token_id = require("game.token.token-id")

---@class Session: Object
---@field _user string|nil Logged-in user name
---@field _permissions PermissionSet|nil While in a game: the server builds it when the game is selected, the client receives its grants with the game data
---@field _connection Connection|nil
---@field _login Login|nil
---@field _game_data_rp GameDataRp
---@field _list_games_rp ListGamesRp
---@field _create_game_rp CreateGameRp
---@field _delete_game_rp DeleteGameRp
---@field _game_deleted_rp GameDeletedRp
---@field _update_token_rp UpdateTokenRp
---@field _token_changed_rp TokenChangedRp
---@field _create_token_rp CreateTokenRp
---@field _delete_token_rp DeleteTokenRp
---@field _token_created_rp TokenCreatedRp
---@field _token_deleted_rp TokenDeletedRp
---@field _update_entry_rp UpdateEntryRp
---@field _entry_changed_rp EntryChangedRp
---@field _create_entry_rp CreateEntryRp
---@field _delete_entry_rp DeleteEntryRp
---@field _entry_created_rp EntryCreatedRp
---@field _entry_deleted_rp EntryDeletedRp
---@field _grants_changed_rp GrantsChangedRp
---@field _game Game|nil The selected game, from `select_game` to `deselect_game` or the logout (server only)
---@field _game_id string|nil The id of the game whose data the client holds, from `set_game_data` to `clear_game_data` or the logout (client only)
---@field _user_menu_screen UserMenuScreen|nil
---@field _game_screen GameScreen|nil The game screen, while the user is in the game (client only)
---@field _assets_workspace_screen AssetsWorkspaceScreen|nil The assets workspace, while it is open (client only)
---@field _assets_workspace_return Screen|nil The screen the workspace was opened from, shown again when it closes
---@field _login_screen LoginScreen|nil The login screen, from `show_login` (at the connect, at a logout) to the next login (client only)
---@field _sign_up_screen SignUpScreen|nil The sign-up screen, from `show_sign_up` to its way back or the next login (client only)
---@field _games_menu_screen GamesMenuScreen|nil Over the menu, from `show_games_menu` (the menu's Games) to its way back or a join (client only)
---@field _join_game_screen JoinGameScreen|nil The games list, from the listing `show_join_game` asked for (the Games menu's Join) to its way back or a join (client only)
---@field _new_game_screen NewGameScreen|nil Over the Games menu, from `show_new_game` (its Create) to its way back or the join of the game created (client only)
---@field _delete_game_screen DeleteGameScreen|nil The games to delete, from the listing `show_delete_game` asked for (the Games menu's Delete) to its way back or the deletion of a game (client only)
---@field _confirm_delete_game_screen ConfirmDeleteGameScreen|nil Over the games to delete, from `confirm_delete_game` (a game picked) to its way back or the deletion (client only)
---@field _new_token_screen NewTokenScreen|nil Over the game, from `show_new_token` to its way back or the token created (client only)
---@field _period lifetime.Token|nil The "logged in" span (client only): the menu screen, the screens of Games, the game screen and their back entries die with it
local Session = class("Session")

---@param a TokenDataValue|EntryValue|nil
---@param b TokenDataValue|EntryValue|nil
---@return boolean
local function _values_equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

---@param data GameData
---@param key string
---@return boolean Whether the key holds an asset path: an `image` property, or `avatar`, which every token draws, when the properties are not readable
local function _is_image(data, key)
    local property = data.token_properties[key]
    if property then
        return property.type == "image"
    end
    return key == "avatar"
end

---@param entry TokenData The client's
---@param token Token|nil Its control, when the shown page has it
---@param key string
---@param value TokenDataValue
local function _set_token_value(entry, token, key, value)
    if key == "position" then
        local x, y = value[1], value[2]
        assert(type(x) == "number" and type(y) == "number", "a position is two numbers")
        if token then
            token:set_position(x, y)
        else
            entry.position = {
                x,
                y
            }
        end
    elseif token then
        token:set_data(key, value)
    else
        entry[key] = value
    end
end

---@param kind EntryKind
---@param id string
---@return string For a log line, an unknown kind too
local function _describe_entry(kind, id)
    if entries.is_kind(kind) then
        return entries.describe(kind, id)
    end
    return string.format("the entry %q of the unknown kind %q", tostring(id), tostring(kind))
end

---@param self Session
---@param user string
local function _on_login(self, user)
    assert(not self._user)
    self._user = user
    if app.is_client then
        app.text_event_manager:set_text_input(false)
        local period = lifetime.attach(lifetime.token("logged in"), self)
        self._period = period
        self._user_menu_screen = UserMenuScreen(self):attach_lifetime(period)
        app.screen_manager:show(self._user_menu_screen)
        if self._login_screen then
            lifetime.destroy(self._login_screen)
            self._login_screen = nil
        end
        if self._sign_up_screen then
            lifetime.destroy(self._sign_up_screen)
            self._sign_up_screen = nil
        end
        app.backstack_manager:push(function()
            self:logout()
        end):attach_lifetime(period)
    end
end

---@param self Session
local function _on_logout(self)
    assert(self._user)
    self._user = nil
    self._permissions = nil
    if app.is_server then
        self:deselect_game()
    else
        self._game_id = nil
        lifetime.destroy(self._period)
        self._period = nil
        self._user_menu_screen = nil
        self._games_menu_screen = nil
        self._join_game_screen = nil
        self._new_game_screen = nil
        self._delete_game_screen = nil
        self._confirm_delete_game_screen = nil
        self._new_token_screen = nil
        self._game_screen = nil
        self._assets_workspace_screen = nil
        self._assets_workspace_return = nil
        self:show_login()
    end
end

---@param connection Connection
function Session:init(connection)
    self._connection = connection
    self._user = nil
    self._permissions = nil
    self._game = nil
    self._game_id = nil
    self._period = nil
    self._user_menu_screen = nil
    self._games_menu_screen = nil
    self._join_game_screen = nil
    self._new_game_screen = nil
    self._delete_game_screen = nil
    self._confirm_delete_game_screen = nil
    self._new_token_screen = nil
    self._game_screen = nil
    self._assets_workspace_screen = nil
    self._assets_workspace_return = nil
    self._login_screen = nil
    self._sign_up_screen = nil
    local login = Login(self, function(user)
        _on_login(self, user)
    end, function()
        _on_logout(self)
    end):attach_lifetime(self)
    self._login = login
    self._game_data_rp = GameDataRp(self):attach_lifetime(self)
    self._list_games_rp = ListGamesRp(self):attach_lifetime(self)
    self._create_game_rp = CreateGameRp(self):attach_lifetime(self)
    self._delete_game_rp = DeleteGameRp(self):attach_lifetime(self)
    self._game_deleted_rp = GameDeletedRp(self):attach_lifetime(self)
    self._update_token_rp = UpdateTokenRp(self):attach_lifetime(self)
    self._token_changed_rp = TokenChangedRp(self):attach_lifetime(self)
    self._create_token_rp = CreateTokenRp(self):attach_lifetime(self)
    self._delete_token_rp = DeleteTokenRp(self):attach_lifetime(self)
    self._token_created_rp = TokenCreatedRp(self):attach_lifetime(self)
    self._token_deleted_rp = TokenDeletedRp(self):attach_lifetime(self)
    self._update_entry_rp = UpdateEntryRp(self):attach_lifetime(self)
    self._entry_changed_rp = EntryChangedRp(self):attach_lifetime(self)
    self._create_entry_rp = CreateEntryRp(self):attach_lifetime(self)
    self._delete_entry_rp = DeleteEntryRp(self):attach_lifetime(self)
    self._entry_created_rp = EntryCreatedRp(self):attach_lifetime(self)
    self._entry_deleted_rp = EntryDeletedRp(self):attach_lifetime(self)
    self._grants_changed_rp = GrantsChangedRp(self):attach_lifetime(self)
    app.asset_manager:register_session(self)
end

---@return string|nil
function Session:get_user()
    return self._user
end

---@return PermissionSet
function Session:get_permissions()
    return assert(self._permissions, "no permissions before the login (on the client: before the game data)")
end

---@param action permissions.Action
---@param kind permissions.Kind|nil
---@param key string|nil
---@return boolean Whether the permissions are in (the game selected on the server, the game data on the client) and grant it
function Session:is_allowed(action, kind, key)
    local set = self._permissions
    return set ~= nil and set:allows(action, kind, key)
end

---@param grants string[]
function Session:set_grants(grants)
    assert(app.is_client)
    self._permissions = PermissionSet(assert(self._user, "grants need a logged-in user"), grants, assert(app.data, "grants need the game data"))
end

---@param id string The game's id, as `join_game` asked for it
---@param data GameData What the server sent, held as `app.data` from now on
---@param grants string[]
function Session:set_game_data(id, data, grants)
    assert(app.is_client)
    self._game_id = id
    app.data = data
    self:set_grants(grants)
    app.asset_manager:set_store(AssetStore(Consts.CLIENT_ROOT .. "/games/" .. id))
end

---@return string|nil The id of the game whose data the client holds (client only)
function Session:get_game_id()
    return self._game_id
end

---Drops the game data, the grants and the store, with the client's copies of the game's assets
function Session:clear_game_data()
    assert(app.is_client)
    local store = app.asset_manager:get_store()
    if store then
        Asset(store:get_root()):remove()
    end
    app.asset_manager:set_store(nil)
    app.data = nil
    self._permissions = nil
    self._game_id = nil
end

---@param id string A game's id, as the client asked for it
---@return boolean ok
---@return string|nil err Why not, for the user
function Session:select_game(id)
    assert(app.is_server)
    local user = assert(self._user, "a game needs a logged-in user")
    local game = assert(app.games):get(id)
    if not game then
        return false, "No such game"
    end
    game:add_player(user, "player")
    local data = game:get_data()
    if self._game then
        self._game:remove_session(self)
    end
    self._game = game
    game:add_session(self)
    self._permissions = PermissionSet(user, permissions.resolve(data, user), data)
    return true
end

---Leaves the selected game, if any: the session is no longer in it and has no grants (server only)
function Session:deselect_game()
    assert(app.is_server)
    if self._game then
        self._game:remove_session(self)
    end
    self._game = nil
    self._permissions = nil
end

---@return boolean Whether the grants changed: the set rebuilt from the selected game's data (server only); `false` without a game
function Session:refresh_permissions()
    assert(app.is_server)
    local game = self._game
    if not game then
        return false
    end
    local user = assert(self._user, "a game needs a logged-in user")
    local data = game:get_data()
    local grants = permissions.resolve(data, user)
    local previous = self._permissions and self._permissions:get_grants() or {}
    self._permissions = PermissionSet(user, grants, data)
    return not _values_equal(previous, grants)
end

---@return Game The selected one (server only)
function Session:get_game()
    return assert(self._game, "no game selected")
end

---@return boolean Whether a game is selected (server only)
function Session:is_in_game()
    return self._game ~= nil
end

---@return GameDeletedRp What the server pushes the deletion of a session's game through
function Session:get_game_deleted_rp()
    return self._game_deleted_rp
end

---@return TokenChangedRp What the server pushes another session's token changes through
function Session:get_token_changed_rp()
    return self._token_changed_rp
end

---@return TokenCreatedRp What the server pushes another session's new tokens through
function Session:get_token_created_rp()
    return self._token_created_rp
end

---@return TokenDeletedRp What the server pushes another session's token deletions through
function Session:get_token_deleted_rp()
    return self._token_deleted_rp
end

---@return EntryChangedRp What the server pushes another session's entry changes through
function Session:get_entry_changed_rp()
    return self._entry_changed_rp
end

---@return EntryCreatedRp What the server pushes another session's new entries through
function Session:get_entry_created_rp()
    return self._entry_created_rp
end

---@return EntryDeletedRp What the server pushes another session's entry deletions through
function Session:get_entry_deleted_rp()
    return self._entry_deleted_rp
end

---@return GrantsChangedRp What the server pushes the session's own grants through when a change made them differ
function Session:get_grants_changed_rp()
    return self._grants_changed_rp
end

---@param id string The token's id as the client holds it now
---@param changes table<string, TokenDataValue> As `UpdateTokenRequest.changes`
---@param new_id string|nil The id the token was renamed to locally (the client renames first, the server confirms or the refusal restores)
function Session:update_token(id, changes, new_id)
    assert(app.is_client)
    self._update_token_rp:send_request({
        id = id,
        new_id = new_id,
        changes = changes
    })
end

---@param id string The token's id as the client holds it
---@param new_id string|nil The id to rename it to first; one the client's data refuses (`token_id.check`) is logged and the token keeps its id
---@param token TokenData|nil The server's entry: every key whose value differs from the client's is applied, the others left alone
function Session:apply_token(id, new_id, token)
    assert(app.is_client)
    local data = app.data
    if not data or not data.tokens[id] then
        return
    end
    local game_screen = self._game_screen
    local control = game_screen and game_screen:get_page():try_find_token(id)
    local changed = false
    if new_id then
        changed = self:_rename_token(data, id, new_id, control)
        id = changed and new_id or id
    end
    if token then
        changed = self:_apply_token_values(data, data.tokens[id], control, token) or changed
    end
    if changed then
        self:_refresh_token_panel(control)
    end
end

---@private
---@param data GameData The client's
---@param id string
---@param new_id string
---@param control Token|nil The token on the shown page
---@return boolean Whether it was renamed
function Session:_rename_token(data, id, new_id, control)
    local reason = token_id.check(data, new_id)
    if reason then
        app:log(string.format("The token %q is not renamed to %q: %s", id, new_id, reason))
        return false
    end
    if control then
        control:set_id(new_id)
    else
        token_id.rename(data, id, new_id)
        if self._permissions then
            self._permissions:rename_key(permissions.Kind.TOKENS, id, new_id)
        end
    end
    return true
end

---@private
---@param data GameData The client's
---@param entry TokenData The client's entry
---@param control Token|nil The token on the shown page
---@param token TokenData The server's entry
---@return boolean Whether a value changed now; an image the store lacks changes once it is downloaded
function Session:_apply_token_values(data, entry, control, token)
    local store = app.asset_manager:get_store()
    ---@type table<string, string>
    local downloads = {}
    local changed = false
    ---@type table<string, TokenDataValue>
    local values = token
    for key, value in pairs(values) do
        if not _values_equal(entry[key], value) then
            if _is_image(data, key) and store and type(value) == "string" and not store:asset(value):get_type() then
                downloads[key] = value
            else
                _set_token_value(entry, control, key, value)
                changed = true
            end
        end
    end
    if next(downloads) then
        ---@type string[]
        local paths = {}
        for _, path in pairs(downloads) do
            table.insert(paths, path)
        end
        app.asset_manager:download_missing_assets(paths, function()
            local alive = control and lifetime.alive(control) and control or nil
            for key, path in pairs(downloads) do
                _set_token_value(entry, alive, key, path)
            end
            self:_refresh_token_panel(alive)
        end)
    end
    return changed
end

---@param id string The new token's id, one `token_id.check` accepts
---@param token TokenData As `CreateTokenRequest.token`
---@param cb (fun(response: CreateTokenResponse))|nil Called with the answer, after it is applied or notified, while the session is alive and logged in
function Session:create_token(id, token, cb)
    assert(app.is_client)
    self._create_token_rp:send_request({
        id = id,
        page = assert(app.data).game.page,
        token = token
    }, function(response)
        if cb and lifetime.alive(self) and self:is_logged_in() then
            cb(response --[[@as CreateTokenResponse]] )
        end
    end)
end

---@param id string A token's id as the client holds it
function Session:delete_token(id)
    assert(app.is_client)
    self._delete_token_rp:send_request({
        id = id
    })
end

---@param id string The new token's id
---@param page string The page it is placed on, a key of `GameData.pages`
---@param token TokenData The server's entry; an avatar the store lacks is downloaded before the token is added
function Session:apply_token_created(id, page, token)
    assert(app.is_client)
    local data = app.data
    if not data or data.tokens[id] then
        app:log(string.format("A new token %q, which this client holds already, ignored", tostring(id)))
        return
    end
    local store = app.asset_manager:get_store()
    local avatar = token.avatar
    if store and type(avatar) == "string" and not store:asset(avatar):get_type() then
        app.asset_manager:download_missing_assets({
            avatar
        }, function()
            if lifetime.alive(self) then
                self:_add_token(id, page, token)
            end
        end)
    else
        self:_add_token(id, page, token)
    end
end

---@private
---@param id string
---@param page string
---@param token TokenData
function Session:_add_token(id, page, token)
    local data = app.data
    if not data or data.tokens[id] then
        app:log(string.format("A new token %q, which this client holds already, ignored", tostring(id)))
        return
    end
    data.tokens[id] = token
    local page_data = data.pages[page]
    if not page_data then
        app:log(string.format("The new token %q is on the page %q, which this client does not hold: in the data only", id, tostring(page)))
        return
    end
    table.insert(page_data.tokens, id)
    local game_screen = self._game_screen
    if game_screen and lifetime.alive(game_screen) then
        local shown = game_screen:get_page()
        if shown:get_data() == page_data then
            shown:add_token(id)
        end
    end
end

---@param id string The deleted token's id
function Session:apply_token_deleted(id)
    assert(app.is_client)
    local data = app.data
    if not data or not data.tokens[id] then
        app:log(string.format("A deletion of the token %q, which this client does not hold, ignored", tostring(id)))
        return
    end
    local game_screen = self._game_screen
    if game_screen then
        local page = game_screen:get_page()
        local control = page:try_find_token(id)
        if control then
            page:remove_token(control)
        end
    end
    token_id.remove(data, id)
    if self._permissions then
        self._permissions:remove_key(permissions.Kind.TOKENS, id)
    end
end

---@param kind EntryKind
---@param id string The entry's id as the client holds it, `entries.GAME_ID` for `game`
---@param changes EntryValues As `UpdateEntryRequest.changes`
---@param new_id string|nil The id to rename it to; nothing is applied before the server answers
function Session:update_entry(kind, id, changes, new_id)
    assert(app.is_client)
    self._update_entry_rp:send_request({
        kind = kind,
        id = id,
        new_id = new_id,
        changes = changes
    })
end

---@param kind EntryKind
---@param id string The new entry's id
---@param entry EntryData|EntryValues As `CreateEntryRequest.entry`
---@param cb (fun(response: CreateEntryResponse))|nil Called with the answer, after it is applied or notified, while the session is alive and logged in
function Session:create_entry(kind, id, entry, cb)
    assert(app.is_client)
    self._create_entry_rp:send_request({
        kind = kind,
        id = id,
        entry = entry
    }, function(response)
        if cb and lifetime.alive(self) and self:is_logged_in() then
            cb(response --[[@as CreateEntryResponse]] )
        end
    end)
end

---@param kind EntryKind
---@param id string The entry's id as the client holds it
function Session:delete_entry(kind, id)
    assert(app.is_client)
    self._delete_entry_rp:send_request({
        kind = kind,
        id = id
    })
end

---@param kind EntryKind
---@param id string The entry's id as the client holds it
---@param new_id string|nil The id the server renamed it to; one the client's data refuses (`entries.check_rename`) is logged and the entry keeps its id
---@param entry EntryData|nil The server's entry: every field set on the client's, a page's token list left as the client holds it
function Session:apply_entry(kind, id, new_id, entry)
    assert(app.is_client)
    local data = app.data
    if not data or not entries.is_kind(kind) or not entries.get(data, kind, id) then
        app:log(string.format("A change of %s, which this client does not hold, ignored", _describe_entry(kind, id)))
        return
    end
    if new_id then
        local reason = entries.check_rename(data, kind, id, new_id)
        if reason then
            app:log(string.format("The %s %q is not renamed to %q: %s", entries.get_noun(kind), id, new_id, reason))
        else
            entries.rename(data, kind, id, new_id)
            if self._permissions then
                self._permissions:rename_key(entries.get_permission_kind(kind), id, new_id)
            end
            id = new_id
        end
    end
    ---@type string|nil
    local page_to_show
    if entry then
        page_to_show = self:_find_page_to_show(data, kind, id, entry)
        ---@type EntryValues
        local values = entry
        ---@type EntryValues
        local changes = {}
        for key, value in pairs(values) do
            if kind ~= "pages" or key ~= "tokens" then
                changes[key] = value
            end
        end
        entries.apply(data, kind, id, changes)
    end
    self:_update_game_screen(kind, id, page_to_show)
end

---@private
---@param data GameData The client's, before the server's entry is applied
---@param kind EntryKind
---@param id string The entry's id after a rename
---@param entry EntryData The server's
---@return string|nil The page the game screen shows again: the new shown page, or the shown page when its image, width or scale changes
function Session:_find_page_to_show(data, kind, id, entry)
    ---@type EntryValues
    local values = entry
    if kind == "game" then
        local page = values.page
        if type(page) == "string" and page ~= data.game.page then
            return page
        end
    elseif kind == "pages" and data.game.page == id then
        local held = data.pages[id]
        if values.image ~= held.image or values.width ~= held.width or values.pixel_per_meter ~= held.pixel_per_meter then
            return id
        end
    end
    return nil
end

---@private
---@param kind EntryKind
---@param id string The entry's id after the change
---@param page string|nil The page to show again, a key of the client's `pages` or one it does not hold
function Session:_update_game_screen(kind, id, page)
    local game_screen = self._game_screen
    if not game_screen or not lifetime.alive(game_screen) then
        return
    end
    if page then
        self:_show_page(page)
    end
    game_screen = self._game_screen
    if game_screen and lifetime.alive(game_screen) then
        game_screen:on_entries_change(kind, id)
    end
end

---@private
---@param id string The page the game screen shows, once its assets are in
function Session:_show_page(id)
    local data = assert(app.data)
    local page = data.pages[id]
    if not page then
        app.notification_manager:notify("Nothing to show: no page you may see")
        self:leave_game()
        return
    end
    self:_download_missing_assets(GameDataRp.list_required_assets(data, page), function()
        local game_screen = self._game_screen
        local current = app.data
        if lifetime.alive(self) and game_screen and lifetime.alive(game_screen) and current and current.game.page == id then
            game_screen:show_page(id)
        end
    end)
end

---@private
---@param paths string[]
---@param cb fun() Called at once when the store has every one, once they are downloaded otherwise
function Session:_download_missing_assets(paths, cb)
    local store = app.asset_manager:get_store()
    ---@type string[]
    local missing = {}
    for _, path in ipairs(paths) do
        if store and not store:asset(path):get_type() then
            table.insert(missing, path)
        end
    end
    if #missing == 0 then
        cb()
    else
        app.asset_manager:download_missing_assets(missing, cb)
    end
end

---@param kind EntryKind
---@param id string The new entry's id
---@param entry EntryData The server's entry
function Session:apply_entry_created(kind, id, entry)
    assert(app.is_client)
    local data = app.data
    if not data or not entries.is_kind(kind) or not entries.can_create(kind) or entries.get(data, kind, id) then
        app:log(string.format("A creation of %s, which this client holds already or cannot hold, ignored", _describe_entry(kind, id)))
        return
    end
    entries.create(data, kind, id, entry)
    self:_update_game_screen(kind, id, nil)
end

---@param kind EntryKind
---@param id string The deleted entry's id
function Session:apply_entry_deleted(kind, id)
    assert(app.is_client)
    local data = app.data
    if not data or not entries.is_kind(kind) or not entries.can_delete(kind) or not entries.get(data, kind, id) then
        app:log(string.format("A deletion of %s, which this client does not hold, ignored", _describe_entry(kind, id)))
        return
    end
    entries.remove(data, kind, id)
    if self._permissions then
        self._permissions:remove_key(entries.get_permission_kind(kind), id)
    end
    self:_update_game_screen(kind, id, nil)
end

---@param grants string[] The session's grants as the server now holds them
function Session:apply_grants(grants)
    assert(app.is_client)
    if not self._user or not app.data then
        app:log("Grants for a session without a game, ignored")
        return
    end
    self:set_grants(grants)
    local game_screen = self._game_screen
    if game_screen and lifetime.alive(game_screen) then
        game_screen:on_grants_change()
    end
end

---@private
---@param control Token|nil A changed token on the shown page
function Session:_refresh_token_panel(control)
    local game_screen = self._game_screen
    if control and game_screen and game_screen:get_selection():get_select_set()[control] then
        game_screen:on_selection_change()
    end
end

---@return Connection
function Session:get_connection()
    return self._connection
end

function Session:show_login()
    assert(app.is_client and not self._user)
    if not self._login_screen then
        self._login_screen = LoginScreen(self._login):attach_lifetime(self)
    end
    app.screen_manager:show(self._login_screen)
end

function Session:show_sign_up()
    assert(app.is_client and not self._user)
    local screen = self._sign_up_screen
    if not screen then
        screen = SignUpScreen(self):attach_lifetime(self)
        self._sign_up_screen = screen
    end
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_sign_up()
    end):attach_lifetime(screen)
end

function Session:close_sign_up()
    assert(app.is_client and self._sign_up_screen)
    local screen = self._sign_up_screen
    self._sign_up_screen = nil
    self:show_login()
    lifetime.destroy(screen)
end

---@param user string
---@param name string
---@param password string
function Session:sign_up(user, name, password)
    assert(app.is_client)
    self._login:sign_up(user, name, password, function(response)
        if response.success and not self:is_logged_in() then
            self:login(user, password)
        end
    end)
end

---@param user string
---@param password string
function Session:login(user, password)
    self._login:login(user, password)
end

function Session:logout()
    self._login:logout()
end

---@return boolean
function Session:is_logged_in()
    return not not self._user
end

function Session:show_games_menu()
    assert(app.is_client)
    local period = assert(self._period, "managing the games needs a logged-in user")
    if self._games_menu_screen then
        lifetime.destroy(self._games_menu_screen)
    end
    local screen = GamesMenuScreen(self):attach_lifetime(period)
    self._games_menu_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_games_menu()
    end):attach_lifetime(screen)
end

function Session:close_games_menu()
    assert(app.is_client and self._games_menu_screen)
    local screen = self._games_menu_screen
    self._games_menu_screen = nil
    self:show_menu()
    lifetime.destroy(screen)
end

---Shows Games again, or the menu when Games was closed meanwhile
---(a listing that answers after its Back)
---@private
function Session:_return_to_games_menu()
    local screen = self._games_menu_screen
    if screen then
        app.screen_manager:show(screen)
    else
        self:show_menu()
    end
end

function Session:show_join_game()
    assert(app.is_client)
    local period = assert(self._period, "the games need a logged-in user")
    self._list_games_rp:send_request({}, function(response)
        if not lifetime.alive(period) then
            return
        end
        local previous = self._join_game_screen
        local screen = JoinGameScreen(self, (response --[[@as ListGamesResponse]] ).games):attach_lifetime(period)
        self._join_game_screen = screen
        app.screen_manager:show(screen)
        app.backstack_manager:push(function()
            self:close_join_game()
        end):attach_lifetime(screen)
        if previous then
            lifetime.destroy(previous)
        end
    end)
end

function Session:close_join_game()
    assert(app.is_client and self._join_game_screen)
    local screen = self._join_game_screen
    self._join_game_screen = nil
    self:_return_to_games_menu()
    lifetime.destroy(screen)
end

function Session:show_new_game()
    assert(app.is_client)
    local period = assert(self._period, "a new game needs a logged-in user")
    if self._new_game_screen then
        lifetime.destroy(self._new_game_screen)
    end
    local screen = NewGameScreen(self):attach_lifetime(period)
    self._new_game_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_new_game()
    end):attach_lifetime(screen)
end

function Session:close_new_game()
    assert(app.is_client and self._new_game_screen)
    local screen = self._new_game_screen
    self._new_game_screen = nil
    self:_return_to_games_menu()
    lifetime.destroy(screen)
end

function Session:show_delete_game()
    assert(app.is_client)
    local period = assert(self._period, "deleting a game needs a logged-in user")
    self._list_games_rp:send_request({}, function(response)
        if not lifetime.alive(period) then
            return
        end
        ---@type GameInfo[]
        local deletable = {}
        for _, info in ipairs((response --[[@as ListGamesResponse]] ).games) do
            if info.deletable then
                table.insert(deletable, info)
            end
        end
        local previous = self._delete_game_screen
        local screen = DeleteGameScreen(self, deletable):attach_lifetime(period)
        self._delete_game_screen = screen
        app.screen_manager:show(screen)
        app.backstack_manager:push(function()
            self:close_delete_game()
        end):attach_lifetime(screen)
        if previous then
            lifetime.destroy(previous)
        end
    end)
end

function Session:close_delete_game()
    assert(app.is_client and self._delete_game_screen)
    local screen = self._delete_game_screen
    self._delete_game_screen = nil
    self:_return_to_games_menu()
    lifetime.destroy(screen)
end

---@param id string A game's id, as `show_delete_game` listed it
---@param name string The game's name, asked about
function Session:confirm_delete_game(id, name)
    assert(app.is_client)
    local period = assert(self._period, "deleting a game needs a logged-in user")
    if self._confirm_delete_game_screen then
        lifetime.destroy(self._confirm_delete_game_screen)
    end
    local screen = ConfirmDeleteGameScreen(self, id, name):attach_lifetime(period)
    self._confirm_delete_game_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_confirm_delete_game()
    end):attach_lifetime(screen)
end

---Back to the games to delete, or where they would have led
function Session:close_confirm_delete_game()
    assert(app.is_client and self._confirm_delete_game_screen)
    local screen = self._confirm_delete_game_screen
    self._confirm_delete_game_screen = nil
    if self._delete_game_screen then
        app.screen_manager:show(self._delete_game_screen)
    else
        self:_return_to_games_menu()
    end
    lifetime.destroy(screen)
end

---The deletion is over: the question and the games to delete go, Games is shown again
---@private
function Session:_close_deletion()
    local confirm, list = self._confirm_delete_game_screen, self._delete_game_screen
    self._confirm_delete_game_screen = nil
    self._delete_game_screen = nil
    self:_return_to_games_menu()
    if confirm then
        lifetime.destroy(confirm)
    end
    if list then
        lifetime.destroy(list)
    end
end

---@param id string A game's id, as `show_delete_game` listed it
function Session:delete_game(id)
    assert(app.is_client)
    local period = assert(self._period, "deleting a game needs a logged-in user")
    self._delete_game_rp:send_request({
        id = id
    }, function(response)
        local deleted = response --[[@as DeleteGameResponse]]
        if lifetime.alive(period) and deleted.success then
            self:apply_game_deleted(assert(deleted.id), assert(deleted.name))
            self:_close_deletion()
        end
    end)
end

---The one path the deleter's answer and the push to the other sessions take:
---the notification, the way out of the game when the client is in it, and the
---data dropped when the client holds that game's
---@param id string
---@param name string
function Session:apply_game_deleted(id, name)
    assert(app.is_client)
    app.notification_manager:notify(string.format("The game %q was deleted", name))
    if self._game_id ~= id then
        return
    end
    if self._game_screen then
        self:leave_game()
    end
    self:clear_game_data()
end

---@param name string
function Session:create_game(name)
    assert(app.is_client)
    local period = assert(self._period, "a new game needs a logged-in user")
    self._create_game_rp:send_request({
        name = name
    }, function(response)
        local created = response --[[@as CreateGameResponse]]
        if lifetime.alive(period) and created.success then
            self:join_game(assert(created.id))
        end
    end)
end

---@param id string A game's id, as `show_join_game` listed it
function Session:join_game(id)
    assert(app.is_client)
    assert_type(id, "string")
    app.screen_manager:show(WaitingScreen("Loading..."))
    if self._new_game_screen then
        lifetime.destroy(self._new_game_screen)
        self._new_game_screen = nil
    end
    if self._join_game_screen then
        lifetime.destroy(self._join_game_screen)
        self._join_game_screen = nil
    end
    if self._confirm_delete_game_screen then
        lifetime.destroy(self._confirm_delete_game_screen)
        self._confirm_delete_game_screen = nil
    end
    if self._delete_game_screen then
        lifetime.destroy(self._delete_game_screen)
        self._delete_game_screen = nil
    end
    if self._games_menu_screen then
        lifetime.destroy(self._games_menu_screen)
        self._games_menu_screen = nil
    end
    self._game_data_rp:send_request({
        game = id
    })
end

function Session:enter_game()
    assert(app.is_client and not self._game_screen)
    if not self._period then -- the data answered a login that is over
        return
    end
    if not app.data then -- the game was deleted while its assets were on their way
        self:show_menu()
        return
    end
    local screen = GameScreen(app.data.game):attach_lifetime(self._period)
    self._game_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:leave_game()
    end):attach_lifetime(screen)
end

function Session:show_menu()
    assert(app.is_client and self._user_menu_screen)
    app.screen_manager:show(self._user_menu_screen)
end

function Session:leave_game()
    assert(app.is_client and self._game_screen)
    if self._assets_workspace_screen then
        lifetime.destroy(self._assets_workspace_screen)
        self._assets_workspace_screen = nil
        self._assets_workspace_return = nil
    end
    if self._new_token_screen then
        lifetime.destroy(self._new_token_screen)
        self._new_token_screen = nil
    end
    self:show_menu()
    lifetime.destroy(self._game_screen)
    self._game_screen = nil
end

---@return GameScreen|nil While the user is in the game
function Session:get_game_screen()
    return self._game_screen
end

function Session:show_new_token()
    assert(app.is_client and self._game_screen, "a new token needs the game")
    local period = assert(self._period, "a new token needs a logged-in user")
    if self._new_token_screen then
        lifetime.destroy(self._new_token_screen)
    end
    local screen = NewTokenScreen(self):attach_lifetime(period)
    self._new_token_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_new_token()
    end):attach_lifetime(screen)
end

function Session:close_new_token()
    assert(app.is_client and self._new_token_screen)
    local screen = self._new_token_screen
    self._new_token_screen = nil
    if self._game_screen then
        app.screen_manager:show(self._game_screen)
    else
        self:show_menu()
    end
    lifetime.destroy(screen)
end

---@return NewTokenScreen|nil While it is open
function Session:get_new_token_screen()
    return self._new_token_screen
end

---@param pick AssetPick|nil A file to choose, for a token's image property
function Session:open_assets_workspace(pick)
    assert(app.is_client and not self._assets_workspace_screen)
    local period = assert(self._period, "the assets workspace needs a logged-in user")
    self._assets_workspace_return = assert(app.screen_manager:get_screen())
    local screen = AssetsWorkspaceScreen(pick):attach_lifetime(period)
    self._assets_workspace_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_assets_workspace()
    end):attach_lifetime(screen)
end

function Session:close_assets_workspace()
    assert(app.is_client and self._assets_workspace_screen)
    local screen, return_screen = self._assets_workspace_screen, assert(self._assets_workspace_return)
    self._assets_workspace_screen = nil
    self._assets_workspace_return = nil
    app.screen_manager:show(return_screen)
    lifetime.destroy(screen)
end

return Session

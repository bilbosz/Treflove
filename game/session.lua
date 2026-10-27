local AssetsWorkspaceScreen = require("game.assets.workspace.assets-workspace-screen")
local CreateGameRp = require("game.create-game-rp")
local GameDataRp = require("game.game-data-rp")
local GameScreen = require("game.game-screen")
local GamesScreen = require("screens.games-screen")
local ListGamesRp = require("game.list-games-rp")
local Login = require("login.login")
local LoginScreen = require("login.login-screen")
local NewGameScreen = require("screens.new-game-screen")
local PermissionSet = require("game.permission-set")
local SignUpScreen = require("login.sign-up-screen")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")
local lifetime = require("lifetime")
local permissions = require("game.permissions")

---@class Session: Object
---@field _user string|nil Logged-in user name
---@field _permissions PermissionSet|nil While in a game: the server builds it when the game is selected, the client receives its grants with the game data
---@field _connection Connection|nil
---@field _login Login|nil
---@field _game_data_rp GameDataRp
---@field _list_games_rp ListGamesRp
---@field _create_game_rp CreateGameRp
---@field _game Game|nil The selected game, from `select_game` to the logout (server only)
---@field _user_menu_screen UserMenuScreen|nil
---@field _game_screen GameScreen|nil The game screen, while the user is in the game (client only)
---@field _assets_workspace_screen AssetsWorkspaceScreen|nil The assets workspace, while it is open (client only)
---@field _assets_workspace_return Screen|nil The screen the workspace was opened from, shown again when it closes
---@field _login_screen LoginScreen|nil The login screen, from `show_login` (at the connect, at a logout) to the next login (client only)
---@field _sign_up_screen SignUpScreen|nil The sign-up screen, from `show_sign_up` to its way back or the next login (client only)
---@field _games_screen GamesScreen|nil The games list, from the listing `show_games` asked for to its way back or a join (client only)
---@field _new_game_screen NewGameScreen|nil Over the games list, from `show_new_game` to its way back or a join (client only)
---@field _period lifetime.Token|nil The "logged in" span (client only): the menu screen, the games and new-game screens, the game screen and their back entries die with it
local Session = class("Session")

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
    self._game = nil
    if app.is_client then
        lifetime.destroy(self._period)
        self._period = nil
        self._user_menu_screen = nil
        self._games_screen = nil
        self._new_game_screen = nil
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
    self._period = nil
    self._user_menu_screen = nil
    self._games_screen = nil
    self._new_game_screen = nil
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
    self._game = game
    self._permissions = PermissionSet(user, permissions.resolve(data, user), data)
    return true
end

---@return Game The selected one (server only)
function Session:get_game()
    return assert(self._game, "no game selected")
end

---@return boolean Whether a game is selected (server only)
function Session:is_in_game()
    return self._game ~= nil
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

function Session:show_games()
    assert(app.is_client)
    local period = assert(self._period, "the games need a logged-in user")
    self._list_games_rp:send_request({}, function(response)
        if not lifetime.alive(period) then
            return
        end
        local previous = self._games_screen
        local screen = GamesScreen(self, (response --[[@as ListGamesResponse]] ).games):attach_lifetime(period)
        self._games_screen = screen
        app.screen_manager:show(screen)
        app.backstack_manager:push(function()
            self:close_games()
        end):attach_lifetime(screen)
        if previous then
            lifetime.destroy(previous)
        end
    end)
end

function Session:close_games()
    assert(app.is_client and self._games_screen)
    local screen = self._games_screen
    self._games_screen = nil
    self:show_menu()
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
    if self._games_screen then
        app.screen_manager:show(self._games_screen)
    else
        self:show_menu()
    end
    lifetime.destroy(screen)
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

---@param id string A game's id, as `show_games` listed it
function Session:join_game(id)
    assert(app.is_client)
    assert_type(id, "string")
    app.screen_manager:show(WaitingScreen("Loading..."))
    if self._new_game_screen then
        lifetime.destroy(self._new_game_screen)
        self._new_game_screen = nil
    end
    if self._games_screen then
        lifetime.destroy(self._games_screen)
        self._games_screen = nil
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
    self:show_menu()
    lifetime.destroy(self._game_screen)
    self._game_screen = nil
end

---@return GameScreen|nil While the user is in the game
function Session:get_game_screen()
    return self._game_screen
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

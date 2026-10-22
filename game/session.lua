local AssetsWorkspaceScreen = require("game.assets.workspace.assets-workspace-screen")
local GameDataRp = require("game.game-data-rp")
local GameScreen = require("game.game-screen")
local Login = require("login.login")
local LoginScreen = require("login.login-screen")
local PermissionSet = require("game.permission-set")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")
local lifetime = require("lifetime")
local permissions = require("game.permissions")

---@class Session: Object
---@field _user string|nil Logged-in user name
---@field _permissions PermissionSet|nil While logged in: the server builds it at login from `app.data`, the client receives its grants with the game data
---@field _connection Connection|nil
---@field _login Login|nil
---@field _game_data_rp GameDataRp
---@field _user_menu_screen UserMenuScreen|nil
---@field _game_screen GameScreen|nil The game screen, while the user is in the game (client only)
---@field _assets_workspace_screen AssetsWorkspaceScreen|nil The assets workspace, while it is open (client only)
---@field _assets_workspace_return Screen|nil The screen the workspace was opened from, shown again when it closes
---@field _login_screen LoginScreen|nil The login screen a logout shows, until the next login (client only)
---@field _period lifetime.Token|nil The "logged in" span (client only): the menu screen, the game screen and their back entries die with it
local Session = class("Session")

---@param self Session
---@param user string
local function _on_login(self, user)
    assert(not self._user)
    self._user = user
    if app.is_server then
        self._permissions = PermissionSet(user, permissions.resolve(assert(app.data), user))
    end
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
    if app.is_client then
        lifetime.destroy(self._period)
        self._period = nil
        self._user_menu_screen = nil
        self._game_screen = nil
        self._assets_workspace_screen = nil
        self._assets_workspace_return = nil
        self._login_screen = LoginScreen(self._login):attach_lifetime(self)
        app.screen_manager:show(self._login_screen)
    end
end

---@param connection Connection
function Session:init(connection)
    self._connection = connection
    self._user = nil
    self._permissions = nil
    self._period = nil
    self._user_menu_screen = nil
    self._game_screen = nil
    self._assets_workspace_screen = nil
    self._assets_workspace_return = nil
    self._login_screen = nil
    local login = Login(self, function(user)
        _on_login(self, user)
        if app.is_client then
            self._user_menu_screen:join_game()
        end
    end, function()
        _on_logout(self)
    end):attach_lifetime(self)
    self._login = login
    self._game_data_rp = GameDataRp(self):attach_lifetime(self)
    app.asset_manager:register_session(self)

    if app.is_client then
        login:login("adam", "krause")
    end
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
---@return boolean Whether the permissions are in (the login on the server, the game data on the client) and grant it
function Session:is_allowed(action, kind, key)
    local set = self._permissions
    return set ~= nil and set:allows(action, kind, key)
end

---@param grants string[]
function Session:set_grants(grants)
    assert(app.is_client)
    self._permissions = PermissionSet(assert(self._user, "grants need a logged-in user"), grants)
end

---@return Connection
function Session:get_connection()
    return self._connection
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

function Session:join_game()
    assert(app.is_client)
    app.screen_manager:show(WaitingScreen("Loading..."))
    self._game_data_rp:send_request({})
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

---The assets workspace over the shown screen (the menu or the game), under
---the period; its back entry closes it
function Session:open_assets_workspace()
    assert(app.is_client and not self._assets_workspace_screen)
    local period = assert(self._period, "the assets workspace needs a logged-in user")
    self._assets_workspace_return = assert(app.screen_manager:get_screen())
    local screen = AssetsWorkspaceScreen():attach_lifetime(period)
    self._assets_workspace_screen = screen
    app.screen_manager:show(screen)
    app.backstack_manager:push(function()
        self:close_assets_workspace()
    end):attach_lifetime(screen)
end

---Shows the screen the workspace was opened from again and destroys the
---workspace with its lists and fields
function Session:close_assets_workspace()
    assert(app.is_client and self._assets_workspace_screen)
    local screen, return_screen = self._assets_workspace_screen, assert(self._assets_workspace_return)
    self._assets_workspace_screen = nil
    self._assets_workspace_return = nil
    app.screen_manager:show(return_screen)
    lifetime.destroy(screen)
end

return Session

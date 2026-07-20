local GameDataRp = require("game.game-data-rp")
local Login = require("login.login")
local LoginScreen = require("login.login-screen")
local UserMenuScreen = require("screens.user-menu-screen")
local WaitingScreen = require("screens.waiting-screen")

---@class Session
---@field _user string|nil Logged-in user name
---@field _connection Connection|nil
---@field _login Login|nil
---@field _game_data_rp GameDataRp
---@field _user_menu_screen UserMenuScreen|nil
---@field _backstack_cb BackstackManagerCb|nil
local Session = class("Session")

---@param self Session
---@param user string
local function _on_login(self, user)
    assert(not self._user)
    self._user = user
    if app.is_client then
        app.text_event_manager:set_text_input(false)
        self._user_menu_screen = UserMenuScreen(self)
        app.screen_manager:show(self._user_menu_screen)
        self._backstack_cb = function()
            self:logout()
        end

        app.backstack_manager:push(self._backstack_cb)
    end
end

---@param self Session
local function _on_logout(self)
    assert(self._user)
    self._user = nil
    if app.is_client then
        app.backstack_manager:pop(self._backstack_cb)
        self._backstack_cb = nil
        self._user_menu_screen = nil
        app.screen_manager:show(LoginScreen(self._login))
    end
end

---@param connection Connection
function Session:init(connection)
    self._connection = connection
    self._user = nil
    local login = Login(self, function(user)
        _on_login(self, user)
        if app.is_client then
            self._user_menu_screen:join_game()
        end
    end, function()
        _on_logout(self)
    end)
    self._login = login
    self._game_data_rp = GameDataRp(self._connection)
    app.asset_manager:register_session(self)

    if app.is_client then
        login:login("adam", "krause")
    end
end

---@return string|nil
function Session:get_user()
    return self._user
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

function Session:release()
    app.asset_manager:unregister_session(self)
    if app.is_client then
        app.backstack_manager:pop(self._backstack_cb)
        self._backstack_cb = nil
    end
    self._login:release()
    self._login = nil
    self._connection = nil
end

return Session
